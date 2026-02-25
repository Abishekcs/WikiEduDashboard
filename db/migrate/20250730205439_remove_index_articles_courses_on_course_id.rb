class RemoveIndexArticlesCoursesOnCourseId < ActiveRecord::Migration[8.0]
  def change
    remove_index :articles_courses,
                 name: :index_articles_courses_on_course_id,
                 if_exists: true
  end
end
