import { getCollection, type CollectionEntry } from 'astro:content';

export type Note = CollectionEntry<'notes'>;

export async function getNotes(): Promise<Note[]> {
  const all = await getCollection('notes', ({ data }) => !data.draft);
  return all.sort((a, b) => b.data.date.getTime() - a.data.date.getTime());
}

// «Ссылаются сюда»: заметки, в тексте которых есть ссылка на /notes/<id>
export function backlinks(target: Note, all: Note[]): Note[] {
  const re = new RegExp(`\\]\\(/notes/${target.id}/?\\)`);
  return all.filter((n) => n.id !== target.id && re.test(n.body ?? ''));
}

// «Похожие»: заметки с общими темами, по числу совпадений
export function related(target: Note, all: Note[], limit = 3): Note[] {
  const mine = new Set(target.data.topics);
  return all
    .filter((n) => n.id !== target.id)
    .map((n) => ({ n, score: n.data.topics.filter((t) => mine.has(t)).length }))
    .filter((x) => x.score > 0)
    .sort((a, b) => b.score - a.score || b.n.data.date.getTime() - a.n.data.date.getTime())
    .slice(0, limit)
    .map((x) => x.n);
}

export const fmtDate = (d: Date) =>
  d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' });
