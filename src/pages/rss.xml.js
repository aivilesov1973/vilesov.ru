import rss from '@astrojs/rss';
import { SITE } from '../data/site';
import { getNotes } from '../lib/notes';

export async function GET(context) {
  const notes = await getNotes();
  return rss({
    title: SITE.title,
    description: SITE.lead,
    site: context.site,
    items: notes.map((n) => ({
      title: n.data.title,
      pubDate: n.data.date,
      description: n.data.description ?? '',
      link: `/notes/${n.id}/`,
    })),
    customData: '<language>ru</language>',
  });
}
