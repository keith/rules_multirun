package main

import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
    "io/ioutil"
    "os"
    "os/exec"
    "os/signal"
    "path/filepath"
    "runtime"
    "strings"
    "sync"
    "syscall"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

func runfile(path string) (string, error) {
	fullPath, err1 := runfiles.Rlocation(path)
	if err1 != nil {
		strippedPath := strings.SplitN(path, "/", 2)[1]
		fullPath2, err2 := runfiles.Rlocation(strippedPath)
		if err2 != nil {
			fmt.Fprintf(os.Stderr, "Failed to lookup runfile for %s %s\n", path, err1.Error())
			fmt.Fprintf(os.Stderr, "also tried %s %s\n", strippedPath, err2.Error())
			return "", err1
		}
		fullPath = fullPath2
	}
	return fullPath, nil
}

func debugEnv() {
	env := os.Environ()
	for _, e := range env {
        if strings.HasPrefix(e, "RUNFILES_") || strings.HasPrefix(e, "BUILD_") || strings.HasPrefix(e, "TEST_") {
                fmt.Println(e)
        }
    }

    manifest := os.Getenv("RUNFILES_MANIFEST_FILE")
    fmt.Println("RUNFILES_MANIFEST_FILE="+manifest)

	// Check that the files can be listed.
	//entries, _ := ListRunfiles()
	//for _, e := range entries {
	//		fmt.Println(e.ShortPath, e.Path)
	//}
}

type Command struct {
	Tag string `json:"tag"`
	Path string `json:"path"`
	Args []string `json:"args"`
	Env map[string]string `json:"env"`
}

type Instructions struct {
	Commands []Command `json:"commands"`
	Jobs int `json:"jobs"`
    Print_command bool `json:"print_command"`
	Keep_going bool `json:"keep_going"`
    Buffer_output bool `json:"buffer_output"`
    Verbose bool `json:"verbose"`
}

func readInstructions(instructionsFile string) (Instructions, error) {
	content, err := ioutil.ReadFile(instructionsFile)
	if err != nil {
		return Instructions{}, fmt.Errorf("failed to read instructions file %q: %v", instructionsFile, err)
	}
	var instr Instructions
	if err = json.Unmarshal(content, &instr); err != nil {
		return Instructions{}, fmt.Errorf("failed to parse file %q as JSON: %v", instructionsFile, err)
	}
	return instr, nil
}

// scriptPath constructs the script path based on the workspace name and the relative path.
func scriptPath(workspaceName, path string) string {
    if filepath.IsAbs(path) {
        return path
    }
    return filepath.Join(workspaceName, path)
}

func runCommand(command Command, bufferOutput bool, verbose bool) (int, string, error) {
    var cmd *exec.Cmd
    args := command.Args
    env := os.Environ() // Convert map to format "key=value"
    for k, v := range command.Env {
        env = append(env, fmt.Sprintf("%s=%s", k, v))
    }

    if verbose {
		cmdStr := command.Path + " " + strings.Join(args, " ")
		fmt.Println("Command line: ", cmdStr)
    }
    cmd = exec.Command(command.Path, args...)
    cmd.Env = env

    var stdoutBuf bytes.Buffer
    if bufferOutput {
        cmd.Stdout = &stdoutBuf
        cmd.Stderr = &stdoutBuf
    } else {
        cmd.Stdout = os.Stdout
        cmd.Stderr = os.Stderr
    }
    
    err := cmd.Run() // Run and wait for the command to complete
    if err != nil {
        if exitError, ok := err.(*exec.ExitError); ok {
            return exitError.ExitCode(), stdoutBuf.String(), nil
        }
        return 0, stdoutBuf.String(), err
    }
    return 0, stdoutBuf.String(), nil
}

func performConcurrently(commands []Command, printCommand bool, bufferOutput bool, verbose bool) bool {
    if (verbose) {
        fmt.Printf("performConcurrently: %d commands\n", len(commands))
    }
    var wg sync.WaitGroup
    success := true
    mu := &sync.Mutex{} // To safely update `success`

    for _, cmd := range commands {
        wg.Add(1)
        go func(cmd Command) {
            defer wg.Done()
            exitCode, output, err := runCommand(cmd, bufferOutput, verbose)
            if err != nil {
                fmt.Println("Error running command:", err)
                mu.Lock()
                success = false
                mu.Unlock()
                return
            }

            if printCommand && bufferOutput {
                // If print command is set, buffer output isn't, we don't print commands
                // TODO: is this correct?!!
                fmt.Println(cmd.Tag)
            }

            if bufferOutput {
                fmt.Print(output) // Print buffered output
            }

            if exitCode != 0 {
                mu.Lock()
                success = false
                mu.Unlock()
            }
        }(cmd)
    }

    wg.Wait() // Wait for all goroutines to finish
    return success
}

func performSerially(commands []Command, printCommand bool, keepGoing bool, verbose bool) bool {
    if (verbose) {
        fmt.Printf("performSerially: %d commands\n", len(commands))
    }
    success := true
    for _, cmd := range commands {
        if printCommand {
            fmt.Println(cmd.Tag)
        }

        // Serial always buffers output, regardless of setting in json
        bufferOutput := false
        code, _, err := runCommand(cmd, bufferOutput, verbose)
        if code != 0 || err != nil {
            if keepGoing {
                success = false
            } else {
                return false
            }
        }

        //fmt.Println(output)
    }
    return success
}

// cancelOnInterrupt calls f when os.Interrupt or SIGTERM is received.
// It ignores subsequent interrupts on purpose - program should exit correctly after the first signal.
func cancelOnInterrupt(ctx context.Context, f context.CancelFunc) {
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	go func() {
		select {
		case <-ctx.Done():
		case <-c:
			f()
		}
	}()
}

func invokingExe() (string) {
    if runtime.GOOS == "windows" {
         exe, _ := os.Executable()
         return exe
    }
    arg0 := os.Args[0]
    if (strings.HasPrefix(arg0, "/")) {
        return arg0
    }
    cwd := os.Getenv("PWD")
    exe := cwd + "/" + arg0
    return exe
}

func windowsRunViaBash(command Command) (bool) {
    if runtime.GOOS == "windows" {
		if (strings.HasSuffix(command.Path, ".bash") || strings.HasSuffix(command.Path, ".bash")) {
			return true
		}
	}
	return false
}

func resolveCommands(commands []Command) ([]Command) {
    var out []Command
    bashPath := ""
    for _, command := range commands {
        path, err := runfile(command.Path)
        if err != nil {
            fmt.Fprintf(os.Stderr, "%+v\n", err)
            os.Exit(1)
        }
        command.Path = path
        if (windowsRunViaBash(command)) {
            if runtime.GOOS == "windows" && bashPath == "" {
                bash, err := exec.LookPath("bash.exe")
                if err != nil {
                    fmt.Errorf("error: bash.exe not found in PATH")
                    os.Exit(1)
                }
                bashPath = bash
            }
            unixPath := strings.Replace(command.Path, "\\", "/", -1)
            command.Args = append([]string{"-c", unixPath + " \"$@\"", "--"}, command.Args...)
            command.Path = bashPath
        }
        out = append(out, command)
    }
    return out
}

func main() {
    verbose := os.Getenv("MULTIRUN_VERBOSE") != ""
	ctx, cancelFunc := context.WithCancel(context.Background())
	defer cancelFunc()
	cancelOnInterrupt(ctx, cancelFunc)

	// Because we are invoked via a symlink, we cannot accept any command line args
	// The instructions file is always adjacent to the symlink location
	exe := invokingExe()

    // We must only set runfiles env if it isn't already set
    if val := os.Getenv("RUNFILES_MANIFEST_FILE"); val == "" {
        if dir := os.Getenv("RUNFILES_DIR"); dir == "" {
            manifestFile := exe + ".runfiles_manifest"
            if verbose {
                fmt.Println("set RUNFILES_MANIFEST_FILE="+manifestFile)
            }
            if err := os.Setenv("RUNFILES_MANIFEST_FILE", manifestFile); err != nil {
                fmt.Println("Failed to set RUNFILES_MANIFEST_FILE")
                os.Exit(1)
            }
        }
    }

	basePath, _ := strings.CutSuffix(exe, ".exe")
	instructionsFile := basePath + ".json"
	instr, err := readInstructions(instructionsFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "%+v\n", err)
		os.Exit(1)
	}

    parallel := instr.Jobs != 1
    printCommand := instr.Print_command
    instr.Commands = resolveCommands(instr.Commands)

    verbose = verbose || instr.Verbose
    if verbose {
        fmt.Println("args[0]: "+os.Args[0])
        fmt.Println("invoking exe: "+exe)
        debugEnv()
        fmt.Println("Read instructions "+instructionsFile)
        b, err := json.MarshalIndent(instr, "", "  ")
        if err != nil {
            fmt.Println("error:", err)
        }
        fmt.Print(string(b))
    }

    var success bool
    if parallel {
        success = performConcurrently(instr.Commands, printCommand, instr.Buffer_output, verbose)
    } else {
        success = performSerially(instr.Commands, printCommand, instr.Keep_going, verbose)
    }

    if success {
        os.Exit(0)
    } else {
        os.Exit(1)
    }
}
