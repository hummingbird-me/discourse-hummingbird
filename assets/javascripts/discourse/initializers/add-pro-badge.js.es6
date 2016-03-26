import { withPluginApi } from 'discourse/lib/plugin-api';

function hasPro(expiry) {
  return parseInt(expiry.toString(), 10) < Date.now();
}

export default {
  name: 'add-pro-badge',
  initialize () {
    withPluginApi('0.1', function (api) {
      api.decorateWidget('poster-name:after', (dec) => {
        const customFields = (dec.attrs && dec.attrs.userCustomFields) || {};

        if (customFields.proExpiresAt && hasPro(customFields.proExpiresAt)) {
          return dec.h('span.mini-badge', 'pro');
        }
      });
    });
  }
};
