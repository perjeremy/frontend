class SavedItem < ActiveRecord::Base
  attr_accessible :item_id
  attr_accessor :item

  has_many :saved_lists, through: :saved_item_positions
  has_many :saved_item_positions

  validates :item_id, presence: true
end
