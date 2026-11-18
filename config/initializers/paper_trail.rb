# Audit trail (paper_trail, jsonb versions table): the user comes from the controller (ApplicationController sets
# whodunnit to the user id); background jobs and imports record none, and the history shows them as "system".
PaperTrail.config.has_paper_trail_defaults = { ignore: %i[updated_at created_at] }
