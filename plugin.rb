# name: hummingbird-onebox
# about: discourse customizations for hummingbird
# version: 0.1
# authors: Hummingbird Media

register_asset "stylesheets/hummingbird_onebox.scss"

class Onebox::Engine::HummingbirdOnebox
  include Onebox::Engine
  include Onebox::Engine::JSON

  TYPES = {
    'anime' => 'anime',
    'a'     => 'anime',
    'manga' => 'manga',
    'm'     => 'manga'
  }
  HOST_REGEX = %r{https?://(?:www\.)?hummingbird\.me}
  TYPE_REGEX = %r{(?<type>#{TYPES.keys.join('|')})}
  SLUG_REGEX = %r{(?<slug>[A-Za-z0-9\-]+)}
  MATCH_REGEX = %r{^#{HOST_REGEX}/#{TYPE_REGEX}/#{SLUG_REGEX}$}

  matches_regexp MATCH_REGEX
  always_https

  def url
    # TODO: switch to APIv16
    "https://hummingbird.me/full_#{type}/#{slug}.json"
  end

  def to_html
    return "<a href=\"#{link}\">#{link}</a>" if media.nil?

    <<-HTML
      <aside class="hb-onebox hb-onebox-#{type}" data-media-type="#{type}"
                                                 data-media-slug="#{slug}">
        <div class="hb-onebox-poster">
          <img src="#{media['poster_image']}">
        </div>
        <div class="hb-onebox-info">
          <h1 class="hb-onebox-header">
            <a href="#{link}" target="_blank" class="track-link">
              #{media['romaji_title']}
            </a>
          </h1>
          <div class="hb-onebox-rating" title="#{media['bayesian_rating']}">
            #{stars_html}
          </div>
          <div class="hb-onebox-synopsis">
            #{media['synopsis']}
            <a class="hb-onebox-readmore">
              read
              <span class="hb-onebox-readmore-more">more</span>
              <span class="hb-onebox-readmore-less">less</span>
            </a>
          </div>
          <div class="hb-onebox-genres">
            #{genres_html}
          </div>
          <div class="hb-onebox-library-entry">
            <div class="hb-spinner">
              <i class="bounce1"></i>
              <i class="bounce2"></i>
              <i class="bounce3"></i>
            </div>
          </div>
        </div>
      </aside>
    HTML
  end

  private

  def type
    TYPES[MATCH_REGEX.match(@url)['type']]
  end

  def slug
    MATCH_REGEX.match(@url)['slug']
  end

  def media
    raw["full_#{type}"]
  end

  def media_type
    case type
      when 'anime'; media['show_type']
      when 'manga'; media['manga_type']
    end
  end

  def title
    media['romaji_title']
  end

  def stars_html
    rating = (media['bayesian_rating'] / 0.5).round * 0.5
    whole_stars = '<i class="fa fa-star"></i>' * rating.floor
    half_stars = '<i class="fa fa-star-half-o"></i>' * (rating % 1 / 0.5)
    empty_stars = '<i class="fa fa-star-o"></i>' * (5 - rating).floor

    "#{whole_stars}#{half_stars}#{empty_stars}"
  end

  def genres_html
    media['genres'].sort.map do |g|
      "<div class=\"hb-onebox-genre\">#{g}</div>"
    end.join
  end
end
