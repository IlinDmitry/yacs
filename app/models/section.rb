class Section < ActiveRecord::Base
  has_and_belongs_to_many :instructors
  validates  :shortname, presence: true, uniqueness: { scope: :listing_id }
  validates  :crn, presence: true
  default_scope { order(shortname: :asc) }
  before_save :sort_periods, if: :periods_changed?
  after_save :update_conflicts!, if: :periods_changed?
  after_save :send_notification

  def send_notification
    SectionsResponder.new.call(self)
  end

  def conflicts_with(section)
    seld.conflict_ids.include? section.id
  end

  def update_conflicts!
    new_conflict_ids = compute_conflict_ids
    old_conflicts = Section.where(id: self.conflicts_ids)
    new_conflicts = Section.where(id: new_conflict_ids)
    Section.transaction do
      (old_conflicts - new_conflicts).each do |old_conflict|
        old_conflict.update_column :conflicts_ids, old_conflict.conflicts_ids - [self.id]
      end
      (new_conflicts - old_conflicts).each do |new_conflict|
        new_conflict.update_column :conflicts_ids, (new_conflict.conflicts_ids | [self.id]).sort!
      end
      self.update_column :conflicts_ids, new_conflict_ids
    end
  end

  private

  def compute_conflict_ids
    Section.find_by_sql("SELECT sections.id FROM sections WHERE sections.id IN
      (SELECT(unnest(COMPUTE_CONFLICT_IDS(#{self.id})))) ORDER BY ID").map(&:id)
  end
end
