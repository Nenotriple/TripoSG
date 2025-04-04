@echo off
setlocal enabledelayedexpansion


:: Display start message
echo [TripoSG Image-to-3D Inference Script]
echo -------------------------------


:: Navigate to the script directory
cd /d %~dp0
echo Working directory set to: %~dp0


:: Check if the virtual environment exists
if not exist "venv\Scripts\activate.bat" (
    echo ERROR: Virtual environment not found.
    echo Please run setup/installation first to create the virtual environment and install dependencies.
    pause
    exit /b 1
)


:: Activate the virtual environment
echo Activating virtual environment...
call "venv\Scripts\activate.bat"
if errorlevel 1 (
    echo ERROR: Failed to activate virtual environment.
    pause
    exit /b 2
)
echo Activated.


:: Set inference argument variables
set "outputDir=."
set "seed=%RANDOM%"
set "numSteps=50"
set "guidance=7.0"
set "enableRMBG=True"
set "dingSound=on"
set "isDownloaded=False"


:: Initialize currentFile variable based on dropped file or prompt for input
if "%~1"=="" (
    goto :prompt_for_file
) else (
    set "currentFile=%~1"
    echo Found input file to process.
)


:: Process files
:process_files
set /a processed=0
set /a failed=0


:: Display processing status for file
echo.
echo -------------------------------
echo Processing: "!currentFile!"


:: Validate file existence
if not exist "!currentFile!" (
    echo ERROR: File "!currentFile!" does not exist.
    set /a failed+=1
    goto :processing_complete
)


:: Extract file extension
for %%F in ("!currentFile!") do set "fileExt=%%~xF"
echo "!fileExt!" | findstr /i ".png .jpg .jpeg .bmp .tif .tiff .webp" >nul
if errorlevel 1 (
    echo WARNING: "!currentFile!" may not be an image file; attempting to process it anyway...
)


:: Run image inference
echo Settings: seed=!seed!, numSteps=!numSteps!, guidance=!guidance!, enableRMBG=!enableRMBG!
python -m scripts.inference_triposg --image-input "!currentFile!" --output-dir "!outputDir!" --seed !seed! --num-inference-steps !numSteps! --guidance-scale !guidance! --rmbg-net-enable !enableRMBG!


:: Handle processing result
if errorlevel 1 (
    echo ERROR: Processing failed for "!currentFile!"
    set /a failed+=1
) else (
    echo SUCCESS: Processed "!currentFile!"
    set /a processed+=1
)


:: Processing complete output
:processing_complete
echo.
echo -------------------------------
echo Processing complete.
echo Successfully processed: !processed! file(s)

:: Delete downloaded file if applicable
if /i "!isDownloaded!"=="True" (
    echo Cleaning up downloaded file...
    del "!currentFile!" 2>nul
    set "isDownloaded=False"
)

:: Play a ding sound to indicate completion
if /i "!dingSound!"=="on" (
    rundll32 user32.dll,MessageBeep
)


:: Check for failed files
if !failed! gtr 0 (
    echo Failed to process: !failed! file(s)
)


:: Check for additional files dropped
if not "%~2"=="" (
    echo.
    echo NOTE: Additional files were dropped but only the first file was processed.
)


:: Randomize seed and prompt for new file input
set "seed=%RANDOM%"
goto :prompt_for_file


:: Prompt for new file input or repeat last image
:prompt_for_file
echo.
echo -------------------------------
echo Enter a filepath or press enter to re-run the last image; type ? to change inference settings:
echo Settings: seed=!seed!, numSteps=!numSteps!, guidance=!guidance!, enableRMBG=!enableRMBG!
set /p image_path="> "


:: Check for backtick to change inference settings
if "!image_path!"=="?" (
    goto :change_inference_settings
)


:: Check if the input is empty and handle re-running last image
if "!image_path!"=="" (
    if defined currentFile (
        echo Re-running last image: "!currentFile!"
        goto :process_files
    ) else (
        echo No previous image available.
        goto :prompt_for_file
    )
)


:: Check if the input is a URL
echo !image_path! | findstr /i "http:// https://" >nul
if not errorlevel 1 (
    echo URL detected. Downloading...
    set "isDownloaded=True"
    for /f "tokens=*" %%a in ("!image_path!") do (
        for %%b in (%%~nxa) do set "downloadedFileName=%%b"
    )
    if "!downloadedFileName!"=="" set "downloadedFileName=downloaded_image.jpg"
    powershell -Command "Invoke-WebRequest -Uri '!image_path!' -OutFile '!downloadedFileName!'"
    if errorlevel 1 (
        echo ERROR: Failed to download the file from URL.
        set "isDownloaded=False"
        goto :prompt_for_file
    )
    echo Downloaded file: !downloadedFileName!
    set "currentFile=!downloadedFileName!"
    goto :process_files
)


:: Check if the input is a file path
if not exist "!image_path!" (
    echo ERROR: File does not exist.
    goto :prompt_for_file
)


:: Remove potential surrounding double-quotes if present
set "currentFile=!image_path:"=!"
set "isDownloaded=False"
goto :process_files


:: Change inference settings
:change_inference_settings
echo.
echo Inference settings:
echo 1. Change outputDir (current: !outputDir!)
echo 2. Change seed (current: !seed!)
echo 3. Change numSteps (current: !numSteps!)
echo 4. Change guidance (current: !guidance!)
echo 5. Toggle completion sound (current: !dingSound!)
echo 6. Toggle background removal (current: !enableRMBG!)
set /p option="Choose an option number to change (or press enter to cancel): "
if "!option!"=="" (
    goto :prompt_for_file
) else if "!option!"=="1" (
    set /p outputDir="Enter output directory: "
) else if "!option!"=="2" (
    set /p seed="Enter seed: "
) else if "!option!"=="3" (
    set /p numSteps="Enter number of steps: "
) else if "!option!"=="4" (
    set /p guidance="Enter guidance scale: "
) else if "!option!"=="5" (
    if /i "!dingSound!"=="on" (
        set "dingSound=off"
        echo Sound notifications disabled.
    ) else (
        set "dingSound=on"
        echo Sound notifications enabled.
    )
) else if "!option!"=="6" (
    if /i "!enableRMBG!"=="True" (
        set "enableRMBG=False"
        echo Background removal disabled.
    ) else (
        set "enableRMBG=True"
        echo Background removal enabled.
    )
) else (
    echo Invalid option.
    pause
)
goto :prompt_for_file


:: End of script
:end
echo.
pause
