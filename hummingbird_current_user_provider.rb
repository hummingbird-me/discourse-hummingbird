class HummingbirdCurrentUserProvider < Auth::CurrentUserProvider
  OLD_COOKIE = "auth_token".freeze
  TOKEN_COOKIE = "token".freeze
  CURRENT_USER_KEY = "_DISCOURSE_CURRENT_USER".freeze
  API_KEY = "_DISCOURSE_API".freeze
  JWT_SECRET = ENV["JWT_SECRET"].freeze

  def initialize(env)
    @env = env
    @request = Rack::Request.new(env) if env
  end

  # May be used early on in the middleware by Discourse to optimize caching.
  def has_auth_cookie?
    [OLD_COOKIE, TOKEN_COOKIE].any? {|x| !@request.cookies[x].nil? }
  end

  # The current user.
  def current_user
    return @env[CURRENT_USER_KEY] if @env.key?(CURRENT_USER_KEY)

    current_user = nil

    # Try to sign in using JWT token
    if @request.cookies[TOKEN_COOKIE]
      token = nil
      begin
        token = JWT.decode(@request.cookies[TOKEN_COOKIE], JWT_SECRET).first
      rescue JWT::DecodeError
      end
      if token
        current_user = User.where(auth_token: token['sub'].to_s).first
        if current_user.nil?
          current_user = HummingbirdCurrentUserProvider.create_or_update_user(token['sub'])
        end
      end
    end

    # Try to sign in using the old token
    if current_user.nil?
      auth_token = @request.cookies[OLD_COOKIE]
      if auth_token && auth_token.strip.length > 0
        current_user = User.where(auth_token: auth_token).first
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

  # Log a user on, set cookies and session etc. We don't need this since our 
  # users log in via the main application, not Discourse.
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
    [OLD_COOKIE, TOKEN_COOKIE].each do |cookie|
      cookies.delete cookie, domain: ".hummingbird.me"
    end
    @env[CURRENT_USER_KEY] = nil
  end

  def self.create_or_update_user(user_id)
    user_data = JSON.parse open("https://hummingbird.me/api/v1/users/#{user_id}?secret=#{ENV['SYNC_SECRET']}").read

    user = nil
    if user_data["name"]
      user = User.where(auth_token: user_id.to_s).first || User.where(username_lower: user_data["name"].downcase).first || User.where(email: user_data["email"]).first || User.new

      user.username = user.name = user_data["name"]
      user.email = user_data["email"]
      user.avatar_template = user_data["avatar"].gsub(/users\/avatars\/(\d+\/\d+\/\d+)\/\w+/, "users/avatars/\\1/{size}")
      user.activate
      user.auth_token = user_id
      user.save!
    end

    user
  rescue
    nil
  end
end
