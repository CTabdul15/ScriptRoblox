local success, result = pcall(function()
    -- 1. Define the URL
    local url = "https://raw.githubusercontent.com/CTabdul15/ScriptRoblox/script/client_side.lua"
    print("--> Attempting to download script from: " .. url)

    -- 2. Download the script content
    local raw_script = game:HttpGet(url)
    print("--> Script downloaded. Size: " .. #raw_script .. " characters.")
    
    -- 3. Check if the download was successful
    if #raw_script < 100 or raw_script:find("404: Not Found") then
        print("--> FATAL ERROR: Download failed! The file was not found (404 Error) or is empty.")
        print("--> Downloaded content: " .. raw_script)
        return -- Stop the script
    end
    
    -- 4. Load and execute the script
    print("--> Script seems valid. Executing now...")
    local script_function = loadstring(raw_script)
    script_function()
    print("--> Script executed without fatal errors.")
end)

-- This part runs ONLY if the script crashed
if not success then
    print("-----------------------------------------------------")
    print("### AN ERROR OCCURRED! ###")
    print("The script could not be loaded. Please copy the message below and send it to me.")
    print("ERROR DETAILS: " .. tostring(result))
    print("-----------------------------------------------------")
end