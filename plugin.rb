# name: hummingbird-onebox
# about: discourse customizations for hummingbird
# version: 0.1
# authors: Hummingbird Media

User.class_eval do
  def self.whitelisted_user_custom_fields(guardian)
    (super(guardian) + 'pro_expires_at').uniq
  end
end
