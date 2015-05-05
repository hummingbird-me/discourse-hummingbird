Discourse.UserRoute.reopen({
  afterModel: function() {
    user = this.modelFor('user');
    user.setProperties({hummingbird: {loaded: false}});
    $.ajax("https://hummingbird.me/users/" + user.get('username'), {
      type: "GET",
      contentType: "application/json; charset=utf-8",
      success: function(data) {
        var hb = data.user;
        user.setProperties({
          hummingbird: {
            loaded: true,
            coverImageStyle: ('background-image: url("'+hb.cover_image_url+'")').htmlSafe(),
            followingCount: hb.following_count,
            follwerCount: hb.follower_count,
            isPro: hb.is_pro,
            bio: hb.bio
          }
        });
      },
      xhrFields: {
        withCredentials: true
      },
      crossDomain: true
    });

    return user.findDetails();
  }
});

