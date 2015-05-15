require "#{Rails.root}/lib/grok"
require "#{Rails.root}/lib/replica"
require "#{Rails.root}/lib/wiki"

#= Imports and updates articles from Wikipedia into the dashboard database
class ArticleImporter
  ################
  # Entry points #
  ################
  def self.update_all_views(all_time=false)
    articles = Article.current
               .where(articles: { namespace: 0 })
               .find_in_batches(batch_size: 30)
    update_views(articles, all_time)
  end

  def self.update_new_views
    articles = Article.current
               .where(articles: { namespace: 0 })
               .where('views_updated_at IS NULL')
               .find_in_batches(batch_size: 30)
    update_views(articles, true)
  end

  def self.update_all_ratings
    articles = Article.current
               .namespace(0).find_in_batches(batch_size: 30)
    update_ratings(articles)
  end

  def self.update_new_ratings
    articles = Article.current
               .where(rating_updated_at: nil).namespace(0)
               .find_in_batches(batch_size: 30)
    update_ratings(articles)
  end

  def self.views_for_article(title, since)
    Grok.views_for_article title, since
  end

  def self.remove_bad_articles_courses
    non_student_cus = CoursesUsers.where(role: [1, 2, 3, 4])
    non_student_cus.each do |nscu|
      # Check if the non-student user is also a student in the same course.
      next unless CoursesUsers.where(
        role: 0,
        course_id: nscu.course_id,
        user_id: nscu.user.id
      ).empty?

      user_articles = nscu.user.revisions
                      .where('date >= ?', nscu.course.start)
                      .where('date <= ?', nscu.course.end)
                      .pluck(:article_id)

      next if user_articles.empty?

      course_articles = nscu.course.articles.pluck(:id)
      possible_deletions = course_articles & user_articles

      to_delete = []
      possible_deletions.each do |pd|
        other_editors = Article.find(pd).editors - [nscu.user.id]
        course_editors = nscu.course.students & other_editors
        to_delete.push pd if other_editors.empty? || course_editors.empty?
      end

      # remove orphaned articles from the course
      nscu.course.articles.delete(Article.find(to_delete))
      Rails.logger.info(
        "Deleted #{to_delete.size} ArticlesCourses from #{nscu.course.title}"
      )
      # update course cache to account for removed articles
      nscu.course.update_cache unless to_delete.empty?
    end
  end

  ##############
  # API Access #
  ##############
  def self.update_views(articles, all_time=false)
    require './lib/grok'
    views, vua = {}, {}
    articles.with_index do |group, _batch|
      threads = group.each_with_index.map do |a, i|
        start = a.courses.order(:start).first.start.to_date
        Thread.new(i) do
          vua[a.id] = a.views_updated_at || start
          if vua[a.id] < Date.today
            since = all_time ? start : vua[a.id] + 1.day
            views[a.id] = self.views_for_article(a.title, since)
          end
        end
      end
      threads.each(&:join)
      group.each do |a|
        a.views_updated_at = vua[a.id]
        a.update_views(all_time, views[a.id])
      end
      views, vua = {}, {}
    end
  end

  def self.update_ratings(articles)
    articles.with_index do |group, _batch|
      ratings = Wiki.get_article_rating(group.map(&:title)).inject(&:merge)
      next if ratings.blank?
      threads = group.each_with_index.map do |a, i|
        Thread.new(i) do
          a.rating = ratings[a.title]
          a.rating_updated_at = Time.now
        end
      end
      threads.each(&:join)
      group.each(&:save)
    end
  end

  # Queries deleted state and namespace for all articles
  def self.update_article_status(articles=nil)
    # TODO: Narrow this down even more. Current courses, maybe?
    local_articles = articles || Article.all
    synced_articles = Utils.chunk_requests(local_articles) do |block|
      Replica.get_existing_articles_by_id block
    end
    synced_ids = synced_articles.map { |a| a['page_id'] }
    deleted_ids = local_articles.pluck(:id) - synced_ids

    # Check to make sure articles haven't been moved
    maybe_deleted_articles = Article.where(id: deleted_ids)

    # These pages have titles that match Articles in our DB with deleted ids
    same_title_pages = Utils.chunk_requests(maybe_deleted_articles) do |block|
      Replica.get_existing_articles_by_title block
    end

    # Update articles whose IDs have changed (keyed on title and namespace)
    same_title_pages.each do |stp|
      article = Article.find_by(
        title: stp['page_title'],
        namespace: stp['page_namespace'],
        deleted: false
      )
      if !article.nil? && deleted_ids.include?(article.id)
        article.update(id: stp['page_id'])
      end
    end

    # Delete articles as appropriate
    local_articles.where(id: deleted_ids).update_all(deleted: true)
    limbo_revisions = Revision.where(article_id: deleted_ids)
    move_or_delete_revisions limbo_revisions

    # Update titles and namespaces based on ids (we trust ids!)
    synced_articles.map! do |sa|
      Article.new(
        id: sa['page_id'],
        title: sa['page_title'],
        namespace: sa['page_namespace'],
        deleted: false  # Accounts for the case of undeleted articles
      )
    end
    update_keys = [:title, :namespace, :deleted]
    Article.import synced_articles, on_duplicate_key_update: update_keys
  end

  def self.resolve_duplicate_articles(articles)
    titles = articles.map(&:title)
    grouped = Article.where(title: titles).group(%w(title namespace)).count
    deleted_ids = []
    grouped.each do |article|
      next unless article[1] > 1
      article_title = article[0][0]
      article_namespace = article[0][1]
      deleted_ids += delete_duplicates article_title, article_namespace
    end

    # At this stage check to see if the deleted articles' revisions still exist
    # if so, move them to their new article ID
    limbo_revisions = Revision.where(article_id: deleted_ids)
    move_or_delete_revisions limbo_revisions
  end

  def self.move_or_delete_revisions(revisions=nil)
    revisions ||= Revision.all
    return if revisions.empty?

    synced_revisions = Utils.chunk_requests(revisions) do |block|
      Replica.get_existing_revisions_by_id block
    end
    synced_ids = synced_revisions.map { |r| r['rev_id'].to_i }

    deleted_ids = revisions.pluck(:id) - synced_ids
    Revision.where(id: deleted_ids).update_all(deleted: true)

    moved_ids = synced_ids - deleted_ids
    moved_revisions = synced_revisions.reduce([]) do |moved, rev|
      moved.push rev if moved_ids.include? rev['rev_id'].to_i
    end
    moved_revisions.each do |moved|
      Revision.find(moved['rev_id']).update(article_id: moved['rev_page'])
    end
  end

  # Delete all articles with the given title
  # and namespace except for the most recently created
  def self.delete_duplicates(title, ns)
    articles = Article.where(title: title, namespace: ns).order(:created_at)
    deleted = articles.where.not(id: articles.last.id)
    deleted.update_all(deleted: true)
    deleted.map(&:id)
  end
end
