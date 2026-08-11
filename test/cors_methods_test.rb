require_relative './minitest_wrapper'

# Guards the invariant that broke tap-to-complete on web: every HTTP verb the API serves
# must appear in the CORS `allow_methods` setting.
#
# PATCH was missing, so the browser preflight for `PATCH /api/placements/:pid` — the only
# way a placement's resolution is written (complete / skip / reopen) — failed. It went
# unnoticed for a long time because the two test layers that should have caught it can't:
# native has no CORS at all, and the frontend's Jest suite mocks the API module. Only a
# real browser against a real server sees it.
#
# Deliberately a static check rather than a request test: `test/test-api.rb` builds a
# trimmed `Api` without `register Sinatra::Cors`, and loading `src/base_api.rb` here would
# merge its routes and settings into that same class for every other suite in the run.
class CorsMethodsTest < MinitestWrapper

  BACKEND_ROOT = File.expand_path('..', __dir__)

  def allow_methods_settings
    File.read(File.join(BACKEND_ROOT, 'src', 'base_api.rb'))
        .scan(/set :allow_methods, '([^']+)'/)
        .flatten
        .map { |v| v.upcase.split(/\s*,\s*/) }
  end

  # The verbs actually routed, read from the route definitions themselves so adding a
  # route with a new verb fails here until CORS is updated to match.
  def routed_verbs
    verbs = Dir[File.join(BACKEND_ROOT, 'src', 'api', '*.rb')]
              .flat_map { |f| File.read(f).scan(/^\s*(get|post|put|patch|delete)\s+['"]/) }
              .flatten
              .map(&:upcase)
              .uniq
    refute_empty verbs, 'found no routes to check — the scan pattern has drifted'
    verbs
  end

  def test_every_cors_block_allows_every_routed_verb
    blocks = allow_methods_settings
    refute_empty blocks, 'no allow_methods settings found in src/base_api.rb'

    blocks.each_with_index do |allowed, i|
      missing = routed_verbs - allowed
      assert_empty missing,
                   "allow_methods block ##{i + 1} is missing #{missing.join(',')} — a browser " \
                   'preflight for those routes will fail even though the routes exist'
    end
  end

  def test_patch_is_allowed
    allow_methods_settings.each_with_index do |allowed, i|
      assert_includes allowed, 'PATCH',
                      "allow_methods block ##{i + 1} must allow PATCH: it is how a placement " \
                      'resolution is written (PATCH /api/placements/:pid)'
    end
  end

  def test_preflight_is_answerable_at_all
    allow_methods_settings.each do |allowed|
      assert_includes allowed, 'OPTIONS', 'OPTIONS must be allowed or no preflight can succeed'
    end
  end

end
