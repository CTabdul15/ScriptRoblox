-- Minimales Test-Skript
print("GitHub Test-Skript gestartet.")

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "GitHub Test ERFOLGREICH!",
        Text = "Das Laden von GitHub funktioniert korrekt.",
        Icon = "rbxassetid://2822746923", -- Info Icon
        Duration = 15
    })
end)