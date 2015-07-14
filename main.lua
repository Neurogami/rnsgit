--[[============================================================================
com.renoise.RnsGit.xrnx/main.lua
============================================================================]]--

--------------------------------------------------------------------------------
-- preferences
--------------------------------------------------------------------------------

local options = renoise.Document.create("RnsGitPreferences") {
  -- ...
}

renoise.tool().preferences = options

-- Invoked each time the apps document (song) was successfully saved.
renoise.tool().app_saved_document_observable:add_notifier(function()
  handle_app_saved_document_notification()
end)


-- handle_app_saved_document_notification
function handle_app_saved_document_notification()
  if (options.show_debug_prints.value) then
    print(("com.renoise.RnsGit: !! handle_app_saved_document "..
      "notification (filename: '%s')"):format(renoise.song().file_name))
  end
end