# name: hummingbird-onebox
# about: discourse customizations for hummingbird
# version: 0.1
# authors: Hummingbird Media

after_initialize do
  User.preloaded_custom_fields << 'pro_expires_at'
end
