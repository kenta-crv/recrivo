class PublishAllExistingQuestions < ActiveRecord::Migration[6.1]
  def up
    return unless table_exists?(:questions)
    return unless column_exists?(:questions, :published)

    Question.reset_column_information
    Question.unscoped.update_all(published: true)
  end

  def down
  end
end
