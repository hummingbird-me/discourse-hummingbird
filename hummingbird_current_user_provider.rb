gem 'jwt', '1.2.0'

class HummingbirdCurrentUserProvider < Auth::CurrentUserProvider
  OLD_TOKEN_COOKIE  = "auth_token"
  NEW_TOKEN_COOKIE  = "token"
  CURRENT_USER_KEY  = "_DISCOURSE_CURRENT_USER"
  API_KEY           = "_DISCOURSE_API"
  JWT_SECRET        = ENV["JWT_SECRET"]

  def initialize(env)
    @env = env
    @request = Rack::Request.new(env) if env
  end

  # May be used early on in the middleware by Discourse to optimize caching.
  def has_auth_cookie?
    old_cookie = @request.cookies[OLD_TOKEN_COOKIE]
    new_cookie = @request.cookies[NEW_TOKEN_COOKIE]
    !old_cookie.nil? && !new_cookie.nil?
  end

  # The current user.
  def current_user
    return @env[CURRENT_USER_KEY] if @env.key?(CURRENT_USER_KEY)

    old_token = @request.cookies[OLD_TOKEN_COOKIE]
    old_token = nil if old_token && old_token.strip.length == 0

    new_token = nil
    if @request.cookies[NEW_TOKEN_COOKIE]
      begin
        new_token = JWT.decode(@request.cookies[NEW_TOKEN_COOKIE], JWT_SECRET)
      rescue JWT::DecodeError, JWT::ExpiredSignature
      end
    end

    current_user = nil

    if old_token
      current_user = User.where(auth_token: old_token).first

      unless current_user
        # User is accessing the forum for the first time. Need to create their user
        # account.
        current_user = HummingbirdCurrentUserProvider.create_or_update_user(auth_token: old_token)
      end
    end

    if new_token
      current_user = User.where(hummingbird_id: new_token['sub']).first

      unless current_user
        current_user = HummingbirdCurrentUserProvider.create_or_update_user(hummingbird_id: new_token['sub'])
      end
    end

    if current_user && current_user.suspended?
      current_user = nil
    end

    if current_user
      current_user.update_last_seen!
      current_user.update_ip_address!(@request.ip)
    end

    # possible we have an api call, impersonate
    unless current_user
      if api_key_value = @request["api_key"]
        api_key = ApiKey.where(key: api_key_value).includes(:user).first
        if api_key.present?
          @env[API_KEY] = true
          api_username = @request["api_username"]

          if api_key.user.present?
            raise Discourse::InvalidAccess.new if api_username && (api_key.user.username_lower != api_username.downcase)
            current_user = api_key.user
          elsif api_username
            current_user = User.where(username_lower: api_username.downcase).first
          end

        end
      end
    end

    @env[CURRENT_USER_KEY] = current_user
  end

  # Log a user on, set cookies and session etc. We don't need this since our users
  # log in via the main application, not Discourse.
  def log_on_user(user, session, cookie)
    raise NotImplementedError
  end

  # API has special rights -- return true if API was detected.
  def is_api?
    current_user
    @env[API_KEY]
  end

  # Log off user.
  def log_off_user(session, cookies)
    cookies.delete OLD_TOKEN_COOKIE, domain: ".hummingbird.me"
    cookies.delete NEW_TOKEN_COOKIE, domain: ".hummingbird.me"
  end

  def self.create_or_update_user(obj = {})
    auth_token = obj[:auth_token]
    user_id = obj[:hummingbird_id]

    return nil if auth_token.nil? && user_id.nil?

    if auth_token
      user_data = JSON.parse open("https://hummingbird.me/api/v1/users/me?auth_token=#{auth_token}").read
    elsif user_id
      user_data = JSON.parse open("https://hummingbird.me/api/v1/users/#{user_id}").read
    end

    user = nil
    if user_data["name"]
      user   = User.where(auth_token: auth_token).first
      user ||= User.where(user_id: user_id).first
      user ||= User.where(username_lower: user_data["name"].downcase).first
      user ||= User.where(email: user_data["email"]).first
      user ||= User.new

      user.username = user.name = user_data["name"]
      user.email = user_data["email"]
      user.avatar_template = user_data["avatar"].gsub(/users\/avatars\/(\d+\/\d+\/\d+)\/\w+/, "users/avatars/\\1/{size}")
      user.activate
      user.auth_token = auth_token if auth_token
      user.hummingbird_id = user_id if user_id
      user.save!
    end
    user
  rescue
    nil
  end
end
