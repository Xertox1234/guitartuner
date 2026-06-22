-- LUMA gear store — starter catalog seed (v1).
--
-- TEMPLATE URLS: every sweetwater_url below is a Sweetwater SEARCH url with no
-- affiliate id. They resolve to a real page today so the in-app tap-through is
-- testable. Before App Store launch, replace each with an affiliate-wrapped
-- product url by EDITING THIS FILE and re-applying it:
--   npx wrangler d1 execute luma --remote --file=seed/store_products.sql
-- Do NOT hand-edit urls directly in production D1 — INSERT OR REPLACE here would
-- silently clobber them back to the template on the next re-seed.
--
-- Idempotent: INSERT OR REPLACE keyed on stable string ids.

INSERT OR REPLACE INTO store_products
  (id, category, name, description, price_hint, sweetwater_url, image_url, is_featured, sort_order)
VALUES
  ('prod-elixir-nanoweb-light', 'strings', 'Elixir Nanoweb Electric, Light (.010-.046)', 'Long-life coated electric strings, light gauge.', '~$13', 'https://www.sweetwater.com/store/search?s=Elixir+Nanoweb+Electric+Light', '', 1, 0),
  ('prod-snark-st2', 'tuners', 'Snark ST-2 Clip-On Tuner', 'Clip-on chromatic tuner for guitar and bass.', '~$15', 'https://www.sweetwater.com/store/search?s=Snark+ST-2', '', 1, 1),
  ('prod-daddario-exl110', 'strings', 'D''Addario EXL110 Nickel Wound', 'Regular light nickel-wound electric strings.', '~$6', 'https://www.sweetwater.com/store/search?s=DAddario+EXL110', '', 0, 2),
  ('prod-ernieball-slinky', 'strings', 'Ernie Ball Regular Slinky', 'Classic .010-.046 nickel-wound electric strings.', '~$6', 'https://www.sweetwater.com/store/search?s=Ernie+Ball+Regular+Slinky', '', 0, 3),
  ('prod-elixir-bass-light', 'strings', 'Elixir Nanoweb Bass, 4-String Light', 'Coated long-life bass strings, light gauge.', '~$30', 'https://www.sweetwater.com/store/search?s=Elixir+Nanoweb+Bass+Light', '', 0, 4),
  ('prod-daddario-exl170', 'strings', 'D''Addario EXL170 Bass', 'Light nickel-wound long-scale bass strings.', '~$22', 'https://www.sweetwater.com/store/search?s=DAddario+EXL170', '', 0, 5),
  ('prod-tc-polytune-clip', 'tuners', 'TC Electronic PolyTune Clip', 'Polyphonic clip-on tuner with strobe mode.', '~$49', 'https://www.sweetwater.com/store/search?s=TC+Electronic+PolyTune+Clip', '', 0, 6),
  ('prod-boss-tu3', 'tuners', 'Boss TU-3 Chromatic Tuner Pedal', 'Stage-grade chromatic tuner pedal.', '~$105', 'https://www.sweetwater.com/store/search?s=Boss+TU-3', '', 0, 7),
  ('prod-dunlop-tortex-60', 'picks', 'Dunlop Tortex Standard .60mm (72-pack)', 'Classic .60mm picks, bulk pack.', '~$22', 'https://www.sweetwater.com/store/search?s=Dunlop+Tortex+Standard+.60mm', '', 0, 8),
  ('prod-fender-351-picks', 'picks', 'Fender 351 Celluloid Picks (12-pack)', 'Medium celluloid picks, 12-pack.', '~$5', 'https://www.sweetwater.com/store/search?s=Fender+351+Celluloid+Picks', '', 0, 9),
  ('prod-fender-player2-strat', 'guitars', 'Fender Player II Stratocaster', 'Versatile double-cut electric guitar.', '~$799', 'https://www.sweetwater.com/store/search?s=Fender+Player+II+Stratocaster', '', 0, 10),
  ('prod-fender-player2-pbass', 'basses', 'Fender Player II Precision Bass', 'Iconic P-Bass tone, modern build.', '~$849', 'https://www.sweetwater.com/store/search?s=Fender+Player+II+Precision+Bass', '', 0, 11);
