module RailsBlog
  class Post < ActiveRecord::Base
    include AASM

    searchable do
      text :title, :body
      string :state
    end

    belongs_to :author, class_name: "User"

    validates_presence_of :title, :body

    before_save :set_permalink
    after_save :sunspot_commit

    default_scope -> { order("created_at DESC") }

    aasm :column => :state do
      state :drafted, :initial => true
      state :unpublished
      state :published
      state :rejected

      event :unpublish do
        transitions :from => :drafted, :to => :unpublished
      end

      event :publish, :after => :set_published_date do
        transitions :from => :unpublished, :to => :published
      end

      event :reject do
        transitions :from => :unpublished, :to => :rejected
      end
    end

    def sunspot_commit
      Sunspot.commit
    end

    def search_description
      self.body.first(200).chomp(" ") + "..."
    end

    def set_permalink
      self.permalink = self.title.parameterize
    end

    def self.grouped_for_archive
      grouped_by_year = self.published.group_by{ |post| post.created_at.year }
      grouped_by_year.each do |year, posts|
        grouped_by_year[year] = posts.group_by{ |post| post.created_at.strftime("%B") }
      end
    end

    def url_params
      [
        self.dated_at.year,
        self.dated_at.month.to_s.rjust(2, "0"),
        self.dated_at.day.to_s.rjust(2, "0"),
        self.permalink
      ]
    end

    def dated_at
      self.published_at || self.created_at
    end

    def set_published_date
      self.published_at = DateTime.now
      self.save
    end

    def description
      ", posted on
      #{self.dated_at.strftime("%B")}
      #{self.dated_at.day.to_s.rjust(2, "0")},
      #{self.dated_at.year}"
    end

  end
end
