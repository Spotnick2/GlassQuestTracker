-- Glass.lua: this addon's instance of the "liquid glass" material.
--
-- The material lives in the embedded library LibGlass-1.0
-- (Libs\LibGlass-1.0, from github.com/Spotnick2/LibGlass through .pkgmeta
-- externals; the TOC loads it first). Material changes are LibGlass PRs, not
-- edits here.
--
-- An instance, not the library itself: its tuning and font registry are
-- Glass Quest Tracker's own and never touch another glass addon's surfaces.
-- The clean material (r6): thin rectangular rims, no grain. No textures of
-- our own: Glass.MEDIA is the library's folder.

GlassQuestTracker = GlassQuestTracker or {}
GlassQuestTracker.Glass = LibStub("LibGlass-1.0"):New({ preset = "clean" })
