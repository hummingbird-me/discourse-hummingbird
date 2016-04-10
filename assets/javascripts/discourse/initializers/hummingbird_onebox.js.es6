import { withPluginApi } from 'discourse/lib/plugin-api';

const STATUSES = {
  anime: [
    'Currently Watching',
    'Plan to Watch',
    'Completed',
    'On Hold',
    'Dropped'
  ],
  manga: [
    'Currently Reading',
    'Plan to Read',
    'Completed',
    'On Hold',
    'Dropped'
  ]
}

var loggedIn;
function isLoggedIn() {
  if (loggedIn == null) loggedIn = !!PreloadStore.get('currentUser');
  // I don't think this case is ever hit, but Just In Case™
  if (loggedIn == null) loggedIn = !!$('.current-user').length;
  return loggedIn;
}

function getLibraryEntry(type, slug) {
  return $.ajax({
    url: `https://hummingbird.me/full_${type}/${slug}.json`,
    xhrFields: { withCredentials: true }
  }).then(function (data) {
    if (type === 'anime') {
      const libraryEntryId = data.full_anime.library_entry_id;
      return data.library_entries.find((x) => x.id === libraryEntryId)
    } else if (type === 'manga') {
      const libraryEntryId = data.full_manga.manga_library_entry_id;
      return data.manga_library_entries.find((x) => x.id === libraryEntryId)
    }
  })
}

function changeLibraryEntry(type, entry, status) {
  const coll = (type === 'manga') ? 'manga_library_entries' : 'library_entries';
  const key = (type === 'manga') ? 'manga_library_entry' : 'library_entry';
  const payload = {};
  payload[key] = Object.assign(entry, {status});

  const path =  entry.id ? `${coll}/${entry.id}` : coll;

  return $.ajax({
    contentType: 'application/json',
    dataType: 'json',
    method: entry.id ? 'PUT' : 'POST',
    url: `https://hummingbird.me/${path}`,
    xhrFields: { withCredentials: true },
    data: JSON.stringify(payload)
  }).then((res) => res[key]);
}

function initLibraryEntry(ob, type, slug) {
  const target = $('.hb-onebox-library-entry', ob);
  const spinner = $('.hb-spinner', target);

  if (isLoggedIn()) {
    getLibraryEntry(type, slug).then(entry => {
      if (!entry) {
        entry = { status: 'Add to Library' }
        entry[`${type}_id`] = slug;
      }
      spinner.hide();
      // Generate a place to cram the current status
      const currentHolder = $('<span>').text(entry.status).appendTo(target);
      $('<b class="caret"></b>').appendTo(target);
      // Generate the menu and bind it
      generateLibraryEntryMenu(type, entry).on('click', (e) => {
        const newStatus = $(e.target).data('status');
        if (newStatus) {
          target.removeClass('hb-onebox-library-entry-errored');
          currentHolder.hide();
          spinner.show();
          changeLibraryEntry(type, entry, newStatus).then((res) => {
            entry = res;
            spinner.hide();
            currentHolder.text(newStatus).show();
          }, () => {
            spinner.hide();
            target.addClass('hb-onebox-library-entry-errored');
            currentHolder.text('Oops! Failed to save').show();
          });
        }
      }).appendTo(target);
      // And make the menu open!
      target.on('click', () => {
        target.toggleClass('hb-onebox-library-entry-open');
      })
    })
  } else {
    const link = $('<a href="https://hummingbird.me/sign-up" target="_blank">');
    link.addClass('hb-onebox-library-entry no-track-link')
    target.replaceWith(link);
    $('<span>').text(`Track this ${type} with Hummingbird`).appendTo(link);
  }
}

function generateLibraryEntryMenu(type, entry) {
  const list = $('<ul class="hb-onebox-library-entry-menu">');
  const statuses = STATUSES[type];

  statuses.forEach((status) => {
    $('<li>').text(status).data('status', status).appendTo(list);
  });

  return list;
}

function initReadMoreToggle(ob) {
  const synopsis = $('.hb-onebox-synopsis', ob),
        readmore = $('.hb-onebox-readmore', ob);

  readmore.on('click', e => {
    synopsis.toggleClass('hb-onebox-synopsis-open');
  })
}

export default {
  name: 'apply-hb-onebox',
  initialize() {
    withPluginApi('0.2', api => {
      api.decorateCooked((post) => {
        $('.hb-onebox', post).each((i, ob) => {
          const $ob = $(ob),
                type = $ob.data('mediaType'),
                slug = $ob.data('mediaSlug'),
                previewMode = $ob.data('previewMode');

          if (!previewMode) {
            initLibraryEntry($ob, type, slug);
          }
          initReadMoreToggle($ob);
        });
      });
    });
  }
};
