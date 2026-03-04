import std.stdio;
import std.file;
import std.path;
import std.process;
import std.array;
import std.string;
import std.algorithm;

// Powershell wrapper logic for the NVM passthru
const string PS_WRAPPER = `
# == NVM Passthru Wrapper ==
function nvm {
    $nvmExe = "$env:NVM_HOME\nvm.exe"
    $nativeCmds = @('install','uninstall','use','list','ls','current','on','off','node_mirror','npm_mirror','version','--version','arch','proxy','root')

    if ($args.Count -eq 0) {
        & $nvmExe
        return
    }

    $firstArg = $args[0].ToString().ToLower()
    
    # Passthru native NVM commands
    if ($nativeCmds -contains $firstArg) {
        & $nvmExe @args
        return
    }

    # Version parameter execution execution
    if ($args[0] -match "^@?(v?\d+\.\d+\.\d+)$") {
        $nodeVersion = $matches[1]
        if (-not $nodeVersion.StartsWith('v')) {
            $nodeVersion = "v$nodeVersion"
        }
        
        $binDir = "$env:NVM_HOME\$nodeVersion"
        if (-not (Test-Path "$binDir\node.exe")) {
            Write-Error "Node version $nodeVersion is not installed in NVM ($binDir\node.exe not found)."
            return
        }

        # Sub-routing logic
        $forwardArgs = @()
        if ($args.Count -gt 1) {
            $forwardArgs = $args[1..($args.Count - 1)]
        }

        # Intercept package managers
        if ($forwardArgs.Count -gt 0 -and $forwardArgs[0] -match '^(npm|npx|pnpm|pnpx|yarn)$') {
            $tool = $forwardArgs[0]
            $toolArgs = @()
            if ($forwardArgs.Count -gt 1) {
                $toolArgs = $forwardArgs[1..($forwardArgs.Count - 1)]
            }
            
            $toolCmd = "$tool.cmd"
            
            # Temporary path override
            $oldPath = $env:PATH
            try {
                $env:PATH = "$binDir;" + $env:PATH
                & $toolCmd @toolArgs
            } finally {
                $env:PATH = $oldPath
            }
        } else {
            # Execute specific node.exe
            & "$binDir\node.exe" @forwardArgs
        }
    } else {
        # Fallback to node.exe
        & node.exe @args
    }
}
# == End NVM Passthru Wrapper ==
`;


void installForPowerShell() {
    auto docsDir = environment.get("USERPROFILE") ~ "\\Documents";
    string[] psPaths = [
        buildPath(docsDir, "PowerShell", "Microsoft.PowerShell_profile.ps1"),
        buildPath(docsDir, "WindowsPowerShell", "Microsoft.PowerShell_profile.ps1")
    ];

    foreach (path; psPaths) {
        if (!exists(dirName(path))) {
            mkdirRecurse(dirName(path));
        }
        
        // Append or write
        bool alreadyInstalled = false;
        if (exists(path)) {
            string content = readText(path);
            if (content.canFind("== NVM Passthru Wrapper ==")) {
                alreadyInstalled = true;
            }
        }
        
        if (!alreadyInstalled) {
            append(path, "\n" ~ PS_WRAPPER ~ "\n");
            writeln("Successfully installed NVM passthru to PowerShell profile: ", path);
        } else {
            writeln("PowerShell profile already has NVM wrapper installed: ", path);
        }
    }
}

void main() {
    writeln("Starting NVM Passthru Environment Setup");
    writeln("-----------------------------------------");
    
    installForPowerShell();
    
    // Launch a new, isolated PowerShell terminal window post-setup
    writeln("Spawning a new PowerShell environment to test changes...");
    spawnProcess(["pwsh.exe", "-NoExit", "-Command", "Write-Host 'NVM Passthru environment loaded. Try: nvm (version) node -v'"]);
}
