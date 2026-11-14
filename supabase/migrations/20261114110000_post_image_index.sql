-- The storage policy "Readers see images of visible posts" compares
-- author_id::text with the object's folder name. Without this index every
-- image request scans all posts; with it only the author's posts with an image.
create index if not exists posts_image_author_text_idx
  on public.posts ((author_id::text))
  where image_url is not null;
