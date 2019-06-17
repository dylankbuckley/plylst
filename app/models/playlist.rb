class Playlist < ApplicationRecord
  belongs_to :user

  validates :name, presence: true

  after_save :build_spotify_playlist

  include Storext.model()
  store_attributes :variables do
    days_ago Integer
    limit Integer, default: 500
    bpm Integer
    days_ago_filter String, default: 'gt'
    bpm_filter String
    release_date_start String
    release_date_end String
    genres String
  end

  def filtered_tracks(current_user)
    days_ago = variables['days_ago']
    days_ago_filter = variables['days_ago_filter'] || 'gt'
    limit = variables['limit'] || 200
    bpm = variables['bpm']
    bpm_filter = variables['bpm_filter']
    release_date_start = variables['release_date_start']
    release_date_end = variables['release_date_end']
    genres = variables['genres']
    
    tracks = current_user.tracks

    if days_ago.present?
      days_ago = days_ago.to_i
      if days_ago_filter.present? and days_ago_filter == 'gt'
        tracks = tracks.where('added_at < ?', days_ago.days.ago).order('added_at ASC')
      elsif days_ago_filter == 'lt'
        tracks = tracks.where('added_at > ?', days_ago.days.ago).order('added_at DESC')
      end
    end

    if bpm.present?
      if bpm_filter.present? and bpm_filter == 'lt'
        tracks = tracks.where("(audio_features ->> 'tempo')::numeric < ?", bpm)
      else
        tracks = tracks.where("(audio_features ->> 'tempo')::numeric > ?", bpm)
      end
    end

    if release_date_start.present? && release_date_end.present?
      tracks = tracks.joins(:album).where('release_date >= ? AND release_date <= ?', release_date_start, release_date_end)
    elsif release_date_start.present?
       tracks = tracks.joins(:album).where('release_date >= ?', release_date_start)
    elsif release_date_end.present?
       tracks = tracks.joins(:album).where('release_date <= ?', release_date_end)
    end

    if genres
      genres = genres.split(/\s*,\s*/)
      tracks = tracks.joins(:artist).where("artists.genres ?| array[:genres]", genres: genres)
    end

    if limit.present?
      tracks = tracks.limit(limit)
    end

    tracks
  end

  def build_spotify_playlist
    BuildPlaylistsWorker.perform_async(self.user.id)
  end
end
