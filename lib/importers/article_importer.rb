# frozen_string_literal: true

require_dependency "#{Rails.root}/lib/replica"
require_dependency "#{Rails.root}/lib/assignment_updater"

#= Imports articles from Wikipedia into the dashboard database
class ArticleImporter
  def initialize(wiki, course = nil)
    @wiki = wiki
    @course = course
    @articles = []
  end

  def import_articles(ids)
    article_ids = ids.map { |id| { 'mw_page_id' => id } }
    articles_data = []
    article_ids.each_slice(40) do |some_article_ids|
      some_article_data = Replica.new(@wiki).get_existing_articles_by_id some_article_ids
      next if some_article_data.nil?
      articles_data += some_article_data
    end
    return if articles_data.empty?
    import_articles_from_replica_data(articles_data)
  end

  def import_articles_by_title(titles)
    # Slice size is limited by max URI length.
    # 40 is too much for some languages, such as bn.wipedia.org
    titles.each_slice(30) do |some_article_titles|
      query = { prop: 'info', titles: some_article_titles, http_method: :post }
      response = WikiApi.new(@wiki).query(query)
      results = response&.data
      next if results.blank?
      results = results['pages']
      next if results.blank?
      import_articles_from_title_query(results)
    end
  end

  # Takes an array like the following:
  # [{"mw_page_id"=>"69830902", "wiki_id"=>5, "title"=>"Ar00", "namespace"=>"2"},
  # ...
  # {"mw_page_id"=>"69834562", "wiki_id"=>1, "title"=>"Some article", "namespace"=>"1"}]
  # Creates article records with that data.
  def import_articles_from_revision_data(data)
    # We rely on the unique index here, mw_page_id and wiki_id
    Article.import data, on_duplicate_key_update: [:title, :namespace]

    return unless @course

    # Make sure the assigned articles for the course that were imported
    # in this batch of edits have titles that match the revision data we just imported.
    mw_page_ids = data.map { |article_hash| article_hash['mw_page_id'].to_i }
    assigned_articles_with_edits = @course.assigned_articles_from_edit_data(@wiki.id, mw_page_ids)
    assigned_articles_with_edits.each do |article|
      AssignmentUpdater.update_assignments_for_article(article)
    end
  end

  private

  def import_articles_from_replica_data(articles_data)
    articles = []
    articles_data.each do |article_data|
      articles << Article.new(mw_page_id: article_data['page_id'],
                              title: article_data['page_title'],
                              namespace: article_data['page_namespace'],
                              wiki_id: @wiki.id)
    end
    Article.import articles, on_duplicate_key_update: [:title, :namespace]
  end

  def import_articles_from_title_query(results)
    articles = []
    results.each_value do |page_data|
      next if page_data['missing']
      next if page_data['invalid']
      articles << Article.new(mw_page_id: page_data['pageid'].to_i,
                              title: page_data['title'].tr(' ', '_'),
                              wiki_id: @wiki.id,
                              namespace: page_data['ns'].to_i)
    end
    Article.import articles, on_duplicate_key_update: [:title, :namespace]
  end
end
