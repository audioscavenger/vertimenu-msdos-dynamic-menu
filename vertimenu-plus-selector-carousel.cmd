@echo OFF
if "%~1" equ "vmenu_OptionSelection" goto :%~1
pushd %~dp0
setlocal enabledelayedexpansion

:: anti-flicker: https://www.dostips.com/forum/viewtopic.php?t=5809
:: define a nbsp (Non-breaking space or no-break space) ALT+0255
:: actually doesn't work
REM set nbsp=ÿ

:top
set DEMO=
set DEBUG=
set VERBOSE=
set PAUSE=echo.
:: enable the line below to debug and pause at places of your choice
REM set PAUSE=pause
set POPUP=false
IF DEFINED DEBUG set VERBOSE=true
verify on

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
set author=audioscavenger@it-cooking.com
set version=5.1.10
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Purpose
::        This batch is a compilation of all the crazy interactive menu examples
::        by Antonio Perez Ayala on https://www.dostips.com/forum/viewtopic.php?f=3&t=6936
::
::        By selecting options in the menu, obtain a list of variables install{product} and version{product}
::        {product} can be anything you like: AA, BB etc
::        Then you process these in your own routines
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Features
::        Vertical menu controlled by cursor keys via Powershell quirk
::        Horizontal carousel to select each option's value (we call it version)
::        Win10 compatible colors with colorless selector fallback for Vista/2012 - findstr trick is disabled
::        Tabbed indentation with parent and children
::        Jump over spacers and disabled options!
::        Multicolumns for selected version and highest detected version
::        Windows like children options toggle when Parent options are toggled
::        Auto attribution of version value to Menu option children without version
::        Dynamic indentation and menu resize
::        (Un)limited number of tab levels
::        CSV-like controlled options
::        Includes _PS_Resize trick to fit the content of the menu
::        Includes comments! How unusual...
::        Maximum 30 options
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: * TODO
::     1. actually include hidden tools choice in the list because selector menu thinks nothing selected if only that
::     1. add -r to arguments to REFRESH remoteVersionsAvailable
::     1. evolve :arguments to getopt
:: 5.1 enhancements and bug-fixes:
::     1. added local versions detection!
::     2. finally a version flip-switch that's blocked at the edges
::     5. bug fix: deselect a tabbed option would disable the next ones
::     7. protect all [x] comparisons between quotes
::    10. introduce export[%%i] to include or not selected products (used for menu parents)
:: 5.0 enhancements and bug-fixes:
::     1. integrated magic vmenu from https://www.dostips.com/forum/viewtopic.php?f=3&t=6936
::     2. added powershell winsize to resize window
::     3. simplified labels definition, format and colors
::     4. unset PAUSE on DEBUG, one may want DEBUG REMOTE
::     5. auto jump disabled option with DO WHILE emulation
::     7. enable disabled sub-options when selecting top option
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:: set local folders
set rootDir=%CD%
set LOGS=%rootDir%\logs
md %LOGS% 2>NUL
set LOG=%LOGS%\%~n0.log
set EXAMPLE_LocalFolder=%rootDir%\install-product-files

:: TMP files management - RANDOM everytime because of file lock by our friend cmd.exe
set DEBUGLOG=ddebug.log
set TMPFILE=%LOGS%\%~n0.%RANDOM%.tmp.txt
set TMPWARN=%LOGS%\%~n0.warning.%RANDOM%.tmp.log
set TMPERR=%LOGS%\%~n0.error.%RANDOM%.tmp.log
set remoteVersionsAvailable=%LOGS%\%~n0.remoteVersionsAvailable.txt
set versionsSelected=%LOGS%\%~n0.versionsSelected.tmp.txt

:start
IF DEFINED DEBUG echo %TIME% :start

:: when connected remotely via a LocalSystem agent, USERNAME=COMPUTERNAME$
IF [%USERNAME:~-1%]==[$] set AUTOMATED=true
IF NOT [%1]==[] (set AUTOMATED=true) ELSE (title %~n0 %version% - %COMPUTERNAME% - %USERNAME%@%USERDNSDOMAIN% %USERDOMAIN%)
IF DEFINED AUTOMATED call :arguments %*
IF %ERRORLEVEL% EQU 99 exit /b 0
call :detect_winVersion
IF NOT DEFINED AUTOMATED call :set_colors
call :prechecks

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: defaults - set your defaults here
:: include your default values here
:defaults
:: Windows Vista / 2012 and below: fallback for absence of colors
IF "%RC%"=="" (set "cursor=^>") ELSE set "cursor= "

:: width of your menu labels
set labelWidth=40

:: width of your indentations
set tabWidth=2

:: how many levels for your sub-menus?
set maxLevels=5

:: comment the line below to always export every options so the "export" column won't be used
set alwaysExportAll=alwaysExportAll

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: defaults

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: menu content
:menuContent

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: pre-selections: 1st field, chose what is pre-selected at start;
:: Each variable 'installXX' is a selector in the menu
:: No field can be NULL because for loop considers multiple separators as a single one
:: field 5 = set of versions available for each option in the nenu
:: It is good practice to set field 3 = product codes all the same length
:: field 4 = color includes a space as first char for color backward compatibility with previous versions of Windows
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: in this example, we also have submenu parents which won't be used, 
:: it all depends on what you want to do after the options are passed back to main.
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::
set "switch="
set "endHeader="
REM ::                    1=b ;  2=c   ;  4=d   ;   3=e    4=f  ;   5=g    ;  6=h
REM :: labelLine format = tab ; select ; export ; product color ; versions ; label
REM set options=1;x;Tools;   ;tools + Rkit ^(cannot remove^)
set           options=1;x;Y;AA; %y%;3.3.0.12 3.2.4.0;AA label             
set options=%options%/2; ;Y;AA1; %y%;3.5.5.3-US;AA1              
set options=%options%/1; ;Y;BB; %y%;1.6.2.11 1.6.2.8;BB label             
set options=%options%/1; ;Y;CC; %y%;5.1.0.67 5.1.0.52 5.1.0.49;CC label             
set options=%options%/2; ;Y;CC1; %y%;5.1.2.30-US 5.1.1.1-US;CC1              
set options=%options%/0; ;Y;spacer; %w%; ; This line is a spacer
set options=%options%/1; ;Y;PA; %y%;5.0.1.34;PA label             
set options=%options%/2; ;Y;PA1; %w%;UFRII_v2.10 PCL6_v2.00;PA1 Submenu 1 xyz         
set options=%options%/2; ;N;PA2ParentWontBeUsed; %w%; ;PA2 Submenu Parent       
set options=%options%/3;x;Y;PA3; %w%;PCL6;PA3 Submenu 2-1 xyz      
set options=%options%/3;x;Y;PA4; %w%;UFRII;PA4 Submenu 2-2 xyz      
set options=%options%/2; ;Y;PB; %w%;1 2 3;xPB label                
set options=%options%/1; ;N;SQLParentWontBeUsed; %w%;2017 2016 2014;SQL Parent menu                
set options=%options%/2;x;Y;SQL1; %w%; ;SQL1                           
set options=%options%/2;x;Y;SQL2; %w%; ;SQL2                           
set options=%options%/0; ;Y;spacer; %w%; ; This line is a spacer
set options=%options%/1; ;Y;EXAMPLEsmthAndReloadMenu; %w%; ;Update available remote versions     

:: calculate number of options here
REM for %%a in ("%options:/=" "%") do set /A lastOption+=1
for %%a in ("%options:/=" "%") do set /A totalOptions+=1

:: :detect_local_installs must be done before options definition and after options defaults
call :detect_local_installs %*

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: menu content
IF NOT DEFINED AUTOMATED call :winsize 120 40 120 9997
REM IF NOT DEFINED DEMO call :EXAMPLE_setupSomeStuff
REM IF DEFINED AUTOMATED call :EXAMPLE_alterVersionsAvailableInMenu & goto :main


:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: menu loop
:menu
:: you could alter the menu options before loading it, here:
REM call :EXAMPLE_alterVersionsAvailableInMenu

:: define tabbed indentations spaces here:
call :vmenu_setTabbedSpaces

:: menu needs to be redrawn with a goto
goto :vmenu_header
REM IF /I NOT [%choice%]==[n] goto :menu
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: menu loop


:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: main program
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: main program
:: from here, no user interaction no more
:main
IF DEFINED VERBOSE echo %TIME% :main

IF DEFINED DEBUG echo call :vmenu_decodeOptions %select%
:: STEP 1: decode binary shift encoded options + setup install{product} and version{product} variables
call :vmenu_decodeOptions %select%

:: STEP 2: (optional) copyParentVersions from Parent menu items into their children
:: the EXAMPLE below will for example, copy the Parent submenu version into its children with empty version.
call :vmenu_copyParentVersions-EXAMPLE

:: EXAMPLE: (optional) menu loop after alteration
:: if installEXAMPLEsmthAndReloadMenu is chosen as an option, 
:: it will call a routine that will alter the menu/versions and then reload the menu
IF "%installEXAMPLEsmthAndReloadMenu%"=="x" call :installsmthAndReloadMenu-EXAMPLE & goto :menu

:: STEP 3: (optional) visualize the options finally selected with their version
call :vmenu_listOptions %select%

:: STEP 4: (optional) validate each version
:: EXAMPLE: :select_versions routine will ask user to post-modify/validate each version selected
call :select_versions

echo menu selection is over. Call your routines here...
REM call :routine1
REM call :routine2
REM call :routine3

pause
goto :end
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: main program
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: main program



:installsmthAndReloadMenu-EXAMPLE
echo do something here to alter the menu options
goto :EOF

:arguments %*
IF DEFINED DEBUG echo %HIGH%%c% %~0 %END%%c% %* %END%

IF /I [%1]==[version]           echo version=%version% & exit /b 99

call :USAGE & exit /b 99
goto :EOF

:USAGE
echo Usage:    %~n0 [ help ^| version ^| whatever you like]
goto :EOF


::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: start of magic vmenu
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:vmenu_header
  cls
  IF DEFINED DEBUG echo %TIME% %~0
  REM echo(%nbsp%
  call :your-logo-here
  REM echo/
  REM echo Example of Check List / Radio Button
  REM echo/
  echo Move selection lightbar with these cursor keys:
  echo Home/End = First/Last, Up/Down = Prev/Next, or via option's first letter, Left/Right = set Version
  echo                                                     selected     local
  echo      [x] tools + Rkit ^(cannot remove^)             ----------- + ----------
  %endHeader%

  if defined switch set "switch=/R"
  call :vmenu_CheckList select="%options%" %switch%
  echo/
  echo/
  if "%select%" equ "0" goto :vmenu_endProg
  if DEFINED DEBUG echo   DEBUG: Binary Options sum: %select%
  
:: example loop
goto :main
:vmenu_endProg
goto :EOF


:vmenu_CheckList select= "option1/option2/..." [/R]
setlocal EnableDelayedExpansion
:: vmenu subroutine activates a CheckList/RadioButton form controlled by cursor control keys
:: RadioButton is now certainly broken but I keep its original code for history purpose

:: %1 = Variable that receive the selection
:: %2 = Options list separated by slash
:: %3 = /R (switch) = Radio Button (instead of Check List)

:: Process /R switch
if /I "%~3" equ "/R" (
  set "Radio=1"
  set "unmark=( )" & set "mark=(o)"
) else (
  set "Radio="
  set "unmark=[ ]" & set "mark=[x]"
)

:: Separate options
set "options=%~2"
set "lastOption=0"
for %%a in ("%options:/=" "%") do (
  set /A lastOption+=1
  set labelLine=%%~a

  REM ::                    1=b ;  2=c   ;  4=d   ;   3=e    4=f  ;   5=g    ;  6=h
  REM :: labelLine format = tab ; select ; export ; product color ; versions ; label
  for /F "tokens=1-6* delims=;" %%b in ("!labelLine!") do (
    set "tab[!lastOption!]=%%~b"
    set "tabs[!lastOption!]=!tabSpaces[%%~b]!"

    REM :: grab selected products and options: an "x" marks the bounty
    set "select[!lastOption!]=[%%~c]"
    set "install%%e=%%~c"
    
    REM :: compatibility with Vista/Server 2012 and below: no colors available
    set export[!lastOption!]=%%~d
    
    REM :: compatibility with Vista/Server 2012 and below: no colors available
    set color=%%~f
    set labelColor[!lastOption!]=!color:~1!
    
    REM :: versions used in the right column carousel
    set "versions=%%~g"
    set "versions[!lastOption!]=%%~g"
    REM :: IMPORTANT: this is where we get the local detected versions found by :detect_local_installs
    call set "versionsFound[!lastOption!]=%%versionsFound%%~e%%"

    set numVersions=0
    set firstVersion=
    set move2Version[!lastOption!]=0
    for %%v in (!versions!) DO (
      set /A numVersions+=1
      IF "!firstVersion!"=="" (
        set firstVersion=done
        set "version[!lastOption!]=%%v"
        set move2Version[!lastOption!]=1
      )
    )
    set numVersions[!lastOption!]=!numVersions!
    REM set labelVersions[!lastOption!]=!thisLabelVersions!
    
    REM :: add spaces after label to LEFT trim it after
    set label=%%~h                                             
    REM :: calculate the label width and setup toggles
    IF %%~b EQU 0 (
      set "toggle[!lastOption!]=off"
    ) ELSE (
      set "toggle[!lastOption!]=on"
      
      REM :: auto-calculate label width based on tabbing
      call set "option[!lastOption!]=%%label:~0,!labelWidth[%%~b]!%%"
    )
  )

  REM :: Below we setup selected menu item with 
  REM :: the line below is real genius as it's a Unix like command expansion in a variable!
  call set "moveSel[%%option[!lastOption!]:~0,1%%]=set sel=!lastOption!"
)
for /L %%j in (1,1,%totalOptions%) DO IF !tab[%%j]! EQU 1 call :vmenu_toggleColor %%j %totalOptions%

if defined Radio set "select[1]=%mark%"

:: Define powershell vmenu working variables
for %%a in ("Enter=13" "Esc=27" "Space=32" "Endd=35" "Home=36" "LeftArrow=37" "RightArrow=39" "UpArrow=38" "DownArrow=40" "LetterA=65" "LetterZ=90") do set %%a
set "letter=ABCDEFGHIJKLMNOPQRSTUVWXYZ"

:: findstr trick - for Server 2012 and under
REM for /F %%a in ('echo prompt $H ^| cmd') do set "BS=%%a"
REM echo %BS%%BS%%BS%%BS%%BS%%BS%      >_

:: Define movements for standard keys
:: Also define left/right options for versions
set "sel=1"
set "moveSel[%Home%]=set sel=1"
set "moveSel[%Endd%]=set sel=%lastOption%"
set "moveSel[%UpArrow%]=set /A sel-=^!^!(sel-1)"
set "moveSel[%DownArrow%]=set /A sel+=^!^!(sel-lastOption)"

:: Read keys via PowerShell  ->  Process keys in Batch
set /P "=Loading vmenu..." < NUL
PowerShell -executionPolicy bypass -Command ^
  Write-Host 0;  ^
  $validKeys = %Endd%..%Home%+%LeftArrow%+%RightArrow%+%UpArrow%+%DownArrow%+%Space%+%Enter%+%Esc%+%LetterA%..%LetterZ%;  ^
  while ($key -ne %Enter% -and $key -ne %Esc%) {  ^
    $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').VirtualKeyCode;  ^
    if ($validKeys.contains($key)) {Write-Host $key}  ^
  }  ^
%End PowerShell%  |  "%~F0" vmenu_OptionSelection

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: THIS IS WHERE WE PASS SELECTED OPTIONS BACK TO :MAIN
:: %1 is actually "select" passed as 1st arg to this routine, since '=' sign counts as MSDOS separator
:: The trick below is called Passing variables from one routine to another: https://ss64.com/nt/endlocal.html
:: By attaching '&' to endlocal, we are able to SET a (group of) variables just before the localisation is ended
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::
endlocal & set "%~1=%errorlevel%"

:: another way of passing more variables to the parent shell:
REM Endlocal&(
REM set "%~1=%errorlevel%"
REM set "versions=%version[1]% %version[2]% %version[3]%")
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:: findstr trick
REM del _
exit /B


:vmenu_toggle sel maxSel
if defined Radio (
  set "select[%Radio%]=%unmark%"
  set "select[%1]=%mark%"
  set "Radio=%1"
) else (
  if "!select[%1]!" equ "%unmark%" (
    set "select[%1]=%mark%"
  ) else (
    set "select[%1]=%unmark%"
  )
  
  call :vmenu_toggleColor %1 %2
)
exit /B


:vmenu_toggleColor sel maxSel
REM :: below we en(dis)able sub-options based on their tab[%%j] value
set lastOne=0
set /A "nextSel=%1+1"
IF "!select[%1]!"=="%mark%" (set toggleNext=on) ELSE set toggleNext=off

for /L %%j in (%nextSel%,1,%2) DO (
  REM :: stop processing if %%j < lastOne
  IF NOT %%j LEQ !lastOne! (
    REM :: stop processing if next tab is ==root
    IF !tab[%%j]! EQU !tab[%1]! exit /b
    REM :: stop processing if next tab is root==1 or ==itself
    IF !tab[%%j]! LSS 2 exit /b
    
    :: at this point, %%j tab is 100% > sel tab
    set "toggle[%%j]=%toggleNext%"
    set lastOne=%%j
    IF "!select[%%j]!%toggleNext%"=="%unmark%on" call :vmenu_toggleColor %%j %2
  )
)
exit /B


:vmenu_OptionSelection
setlocal EnableDelayedExpansion

rem Wait for PS code start signal
set /P "keyCode="
set /P "="

set "endHeader=exit /B"
:vmenu_ReDraw
:: vmenu_ReDraw draws every line after each key press
:: Clear the screen and show the list:
call :vmenu_header

  REM :: anti flicker trick: doesn't work
  REM echo(%nbsp%
  < NUL (for /L %%i in (1,1,%lastOption%) do (
      set "num=  %%i"
      set "labelVersion=!version[%%i]!                    "
      set "labelversionsFound=!versionsFound[%%i]!                    "
      IF DEFINED DEBUG (
        set ddebug=!toggle[%%i]!    !move2Version[%%i]!
        set ddebugToggle=!toggle[%%i]!    !move2Version[%%i]!
        echo !ddebugToggle!>>%DEBUGLOG%
      )
      if !tab[%%i]! EQU 0 (
        REM :: spacer
        echo.!ddebug!
      ) ELSE (
        if "!toggle[%%i]!" equ "off" (
          REM :: this line is disabled:
          echo  !num:~-2!!tabs[%%i]!%HIGH%%k%!select[%%i]! !option[%%i]! !labelVersion:~0,11!%END% ^| !labelversionsFound:~0,20!!ddebug!
          ) ELSE (
          if "%%i" equ "%sel%" (
            REM :: this line is active AND highlighted
            
            REM :: findstr trick
            REM set /P "=%k%!tab[%%i]!%END%!num:~-2! !select[%%i]!  "
            REM findstr /A:17 . "!option[%%i]!\..\_" NUL
            
            REM :: We show horizontal carousel only if there is more than one version available;
            REM :: also we want to show the direction where the other versions are
            IF !numVersions[%%i]! GTR 1 (
              IF !move2Version[%%i]! EQU !numVersions[%%i]! (
                REM :: last version is shown
                echo %cursor%!num:~-2!!tabs[%%i]!!select[%%i]!%cursor%%RC%%k%!option[%%i]!%END%^<%RB%%w%!labelVersion:~0,11!%END%]^| !labelversionsFound:~0,20!!ddebug!
              ) ELSE (
                IF !move2Version[%%i]! EQU 1 (
                  REM :: first version is shown
                  echo %cursor%!num:~-2!!tabs[%%i]!!select[%%i]!%cursor%%RC%%k%!option[%%i]!%END%[%RB%%w%!labelVersion:~0,11!%END%^>^| !labelversionsFound:~0,20!!ddebug!
                ) ELSE (
                  REM :: middle versions are shown
                  echo %cursor%!num:~-2!!tabs[%%i]!!select[%%i]!%cursor%%RC%%k%!option[%%i]!%END%^<%RB%%w%!labelVersion:~0,11!%END%^>^| !labelversionsFound:~0,20!!ddebug!
                )
              )
            ) ELSE (
              REM :: only one version is shown
              echo %cursor%!num:~-2!!tabs[%%i]!!select[%%i]!%cursor%%RC%%k%!option[%%i]!%END%[!labelVersion:~0,11!%END%]^| !labelversionsFound:~0,20!!ddebug!
            )
          ) else (
            REM :: this line is active but not highlighted
            IF "!select[%%i]!"=="%unmark%" (set versionColor=) ELSE set versionColor=%HIGH%
            echo  !num:~-2!!tabs[%%i]!!select[%%i]! !labelColor[%%i]!!versionColor!!option[%%i]! !labelVersion:~0,11!%END% ^| !labelversionsFound:~0,20!!ddebug!
          )
        )
      )
    )
  )
  echo/
  set /P "=Space=(De)Select, Enter=Continue, Esc=Cancel" < NUL

  REM :: Get a keycode from PowerShell
  set /P "keyCode="
  set /P "="

  REM :: Process it: check for action keys
  if %keyCode% equ %Enter% goto :vmenu_encodeSelection
  if %keyCode% equ %Esc% exit 0
  
  REM :: we process Left/Right only if numVersions > 1
  IF !numVersions[%sel%]! GTR 1 (
    set lastVersion=0
    if %keyCode% equ %LeftArrow% (
      for %%v in (!versions[%sel%]!) DO (
        set /A lastVersion+=1
        IF "!version[%sel%]!"=="%%v" IF !lastVersion! GTR 1 set /A "move2Version[%sel%]-=1"
      )
    )
    if %keyCode% equ %RightArrow% (
      for %%v in (!versions[%sel%]!) DO (
        set /A lastVersion+=1
        IF "!version[%sel%]!"=="%%v" IF !lastVersion! LSS !numVersions[%sel%]! set /A "move2Version[%sel%]+=1"
      )
    )
    
    REM :: below we flip-switch the version after Left/Right is pressed
    IF !lastVersion! GTR 0 (
      REM :: The trick below can be used to rotate versions indefinitely back and forth:
      REM IF !move2Version! GTR !lastVersion! set move2Version=1
      REM IF !move2Version! LEQ 0 set move2Version=!lastVersion!
      set lastVersion=0
      
      REM :: Cannot use '!' in the tokens= part, that's too bad:
      REM for /f "tokens=%move2Version[!sel!]%" %%v in ("!versions[%sel%]!") DO set "version[%sel%]=%%v" & set "versionsFound[%sel%]=%%v"
      
      REM :: Using ! for the calculated token doesn't work, you need a full-fledge loop with increment
      for %%v in (!versions[%sel%]!) DO (
        set /A lastVersion+=1
        IF !lastVersion! EQU !move2Version[%sel%]! set "version[%sel%]=%%v"
      )
    )
  )
  
  REM :: below we (un)mark options after space is pressed
  if %keyCode% equ %Space% (
    call :vmenu_toggle %sel% %lastOption%
    goto :vmenu_ReDraw
  )

  REM :: Process it: check for move keys
  if %keyCode% lss %LetterA% goto :vmenu_jumpSelection
  REM :: Below we process pressed key from A-Z
  REM :: Last Letter option wins when multiple labels start with same Letter
  set /A keyCode-=LetterA
  set "keyCode=!letter:~%keyCode%,1!"
  :vmenu_jumpSelection
  !moveSel[%keyCode%]!
  REM :: jump next one if this is a spacer - first and last options cannot be a spacer
  REM :: BUG: this works only for Arrows Up/Down, for Letters you actually can end on a disabled option
  if "!toggle[%sel%]!"=="off" !moveSel[%keyCode%]!

  REM :: jump next one if this is disabled - DO WHILE emulation
  REM :: This cannot work if first or last option is disabled
  :vmenu_whileDisabled
  IF DEFINED DEBUG call echo toggle[%sel%]=!toggle[%sel%]! %lastOption%   moveSel[%keyCode%]=!moveSel[%keyCode%]!>>%DEBUGLOG%
  REM :: the loop below will jump to next selection that's enabled when pressing a Letter,
  REM :: if the letter leads to a disabled option, by forcing using an Arrow instead
  if "!toggle[%sel%]!" equ "off" (
    if %keyCode% GEQ %LetterA% (
      if %sel% lss %lastOption% (set keyCode=38) ELSE set keyCode=40
      !moveSel[%keyCode%]!
    )
  ) ELSE goto :vmenu_whileEnd
  REM keyCode 40 = up, 38 = down
  if %keyCode% equ 38 (set /A "sel-=1") ELSE set /A "sel+=1"
  goto :vmenu_whileDisabled
  :vmenu_whileEnd

  REM :loop_antiflicker
  REM if "%time:~-1%"=="!time:~-1!" goto :loop_antiflicker
goto :vmenu_ReDraw

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: :vmenu_encodeSelection will create the binary encoded errorlevel used by :vmenu_decodeOptions
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:vmenu_encodeSelection
set "sel="
del /f /q %versionsSelected% >NUL 2>NUL
:: We need to process options in reverse order because that's how we'll pop then out of the errorlevel
for /L %%i in (1,1,%lastOption%) do (
  REM :: we always export all versions because we process every options in reverse order
  echo "!version[%%i]!">>%versionsSelected%
  
  REM :: 1<<x = 2 power x
  REM :: To get the original selections, just for loop in reverse and substract each power values of 2
  REM :: We also make sure we select only those which are not disabled by checking for !toggle[%%i]!
  if "!select[%%i]!!toggle[%%i]!" equ "%mark%on" (
    REM :: We also export only the products tagged "Y" for export unless alwaysExportAll is set
    REM :: Beware: by doing so, you do not export Parent menu items and cannot copy their version into their children in :vmenu_copyParentVersions
    if /I "%alwaysExportAll%"=="alwaysExportAll" (
      set /A "sel+=1<<%%i"
    ) ELSE (
      if /I "!export[%%i]!"=="Y" (
        set /A "sel+=1<<%%i"
      )
    )
  )
)

if NOT DEFINED sel set "sel=0"
:: BUG: there is a MAX value for %sel%: ERRORLEVEL cannot be higher than 1357508192 > 2^30 = 30 options maximum
exit %sel%
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:vmenu_decodeOptions %select%
IF DEFINED DEBUG echo %~0 %1 with lastOption=%lastOption%
:: %binarySum% is a binary addition: sum of all selected options as power of 2
:: BUG: there is a MAX value for binarySum: ERRORLEVEL cannot be higher than 1357508192 > 2^30 = 30 options maximum
set binarySum=%1

:: Separate options
:: TODO: this could be exported as a separate routine since we need that to reverse option selections
set "lastOption=0"
for %%a in ("%options:/=" "%") do (
  REM ::                    1=b ;  2=c   ;  4=d   ;   3=e    4=f  ;   5=g    ;  6=h
  REM :: labelLine format = tab ; select ; export ; product color ; versions ; label
  set /A lastOption+=1
  set labelLine=%%~a
  for /f "tokens=1-6* delims=;" %%b in ("!labelLine!") do (
    set product[!lastOption!]=%%~e
  )
)

:: decode each option
:: %select% is a binary addition: sum of all selected options as power of 2
for /L %%i in (%lastOption%,-1,1) do (
  REM :: overwrite whatever install is detected first:
  call set install!product[%%i]!= 
  set /A "thisOne=1<<%%i"
  REM :: (sign bit -> 0) An arithmetic shift: https://ss64.com/nt/set.html
  REM :: { 1 Lsh 1 = binary 01 Lsh 1 = binary 010   = decimal 2 }
  REM :: { 1 Lsh 2 = binary 01 Lsh 2 = binary 0100  = decimal 4 }
  REM :: { 1 Lsh 3 = binary 01 Lsh 3 = binary 01000 = decimal 8 }
  REM :: etc
  IF !binarySum! GEQ !thisOne! (
    REM :: substract arithmetic shift from binarySum and continue
    REM :: by doing so, we extract each selected option. There is a limit tho:
    set /A "binarySum-=1<<%%i"
    call set install!product[%%i]!=x
  
    REM :: grab selectedVersion for product[%%i]
    set line=0
    for /F %%v in (%versionsSelected%) do set /A line+=1 && IF !line! EQU %%i call set "version!product[%%i]!=%%~v"
    IF DEFINED DEBUG call echo   DEBUG1: Now we can execute option %%i = install!product[%%i]! with version version!product[%%i]!=%%version!product[%%i]!%%
  )
)
goto :EOF

:vmenu_copyParentVersions-EXAMPLE
IF DEFINED DEBUG echo %~0 %1 with lastOption=%lastOption%
:: EXAMPLE: post-process options 
:: This example will attribute parent selection version to its children with empty version.
:: Don't use it if you are OK with products with empty versions
echo.
for /L %%n in (1,1,%lastOption%) do (
  call set "install=%%install!product[%%n]!%%"
  IF "!install!"=="x" (
    call set "thisVersion=%%version!product[%%n]!%%"
    IF NOT "!thisVersion!"=="" (
      set lastVersion=!thisVersion!
    ) ELSE (
      call set "version!product[%%n]!=!lastVersion!"
    )
    IF DEFINED DEBUG call echo   DEBUG2: Now we can execute option %%n = install!product[%%n]! with version version!product[%%n]!=%%version!product[%%n]!%%
  )
)
goto :EOF

:vmenu_setTabbedSpaces
for /L %%L in (1,1,%maxLevels%) DO (
  for /L %%s in (1,1,%tabWidth%) DO (
    set "tabSpaces=!tabSpaces! "
  )
  set "tabSpaces[%%L]=!tabSpaces!"
  set /A "labelWidth[%%L]=labelWidth-thisTabWidth"
  set /A thisTabWidth=thisTabWidth+tabWidth
)

goto :EOF

:vmenu_listOptions %select%
IF DEFINED DEBUG echo %~0 %1 with lastOption=%lastOption%
set binarySum=%1

:: %select% is a binary addition: sum of all selected options as power of 2
echo.
for /L %%i in (%lastOption%,-1,1) do (
  set /A "thisOne=1<<%%i"
  IF !binarySum! GEQ !thisOne! (
    set /A "binarySum-=1<<%%i"
    IF DEFINED DEBUG call echo   DEBUG3: Now we can execute option %%i = install!product[%%i]! with version version!product[%%i]!=%%version!product[%%i]!%%
  )
)
goto :EOF

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: end of magic menu
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


:prechecks
IF DEFINED DEBUG echo %HIGH%%c% %~0 %END%%c% %* %END%
del /f /q %LOGS%\%~n0.*.tmp.* 2>NUL

for %%x in (powershell.exe) do (set powershell=%%~$PATH:x)
IF NOT DEFINED powershell call :error %~0: powershell NOT FOUND

:: test %TMP% exist and write access, i've seen cases where %TMP% is set but actually don't exist
echo]>%TMPFILE%
IF %ERRORLEVEL% NEQ 0 call :error %~0: NO writeable folder found, please logoff to reload environment... EXIT & %PAUSE% & exit

goto :EOF



:::::::::::::::::::::::::::::::::::::::::::::::: technical functions
:detect_winVersion
IF DEFINED DEBUG echo %HIGH%%c% %~0 %END%%c% %* %END%
set osType=workstation
wmic os get Caption /value | findstr Server >%TMP%\wmic.%RANDOM%.tmp
IF %ERRORLEVEL% EQU 0 set osType=server

:: https://www.lifewire.com/windows-version-numbers-2625171
IF [%osType%]==[workstation] (
  ver | findstr /C:"Version 10.0" && set WindowsVersion=10& goto :EOF
  ver | findstr /C:"Version 6.3" && set WindowsVersion=8.1& goto :EOF
  ver | findstr /C:"Version 6.2" && set WindowsVersion=8& goto :EOF
  ver | findstr /C:"Version 6.1" && set WindowsVersion=7& goto :EOF
  ver | findstr /C:"Version 6.0" && set WindowsVersion=Vista& goto :EOF
  ver | findstr /C:"Version 5.1" && set WindowsVersion=XP& goto :EOF
) ELSE (
  for /f "tokens=4" %%a in (%TMP%\wmic.%RANDOM%.tmp) do set WindowsVersion=%%a
)
goto :EOF

:set_colors
set colorCompatibleVersions=-8-8.1-10-2016-2019-
IF DEFINED WindowsVersion IF "!colorCompatibleVersions:-%WindowsVersion%-=_!"=="%colorCompatibleVersions%" goto :EOF

set END=[0m
set HIGH=[1m
set Underline=[4m
set REVERSE=[7m

REM echo [101;93m NORMAL FOREGROUND COLORS [0m
set k=[30m
set r=[31m
set g=[32m
set y=[33m
set b=[34m
set m=[35m
set c=[36m
set w=[37m

REM echo [101;93m NORMAL BACKGROUND COLORS [0m
set RK=[40m
set RR=[41m
set RG=[42m
set RY=[43m
set RB=[44m
set RM=[45m
set RC=[46m
set RW=[47m

goto :EOF
:: BUG: some space are needed after :set_colors


:your-logo-here
echo.
echo.
echo    %y%                    __   __                  __        __   ___  __  tm
echo    %y%                   ^|  \ /  \ ^|  ^| ^|\ ^| ^|    /  \  /\  ^|  \ ^|__  ^|__) 
echo    %y%                   ^|__/ \__/ ^|/\^| ^| \^| ^|___ \__/ /~~\ ^|__/ ^|___ ^|  \ 
echo    %c%   ,;            
echo    %c% `7MMpMMMb.pMMMb.
echo    %c%   MM    MM    MM
echo    %c%   MM    MM    MM
echo    %c%   MM    MM    MM
echo    %c% .JMML  JMML  JMML
echo.%END%
goto :EOF


:error "msg"
echo.%r%
echo ==============================================================
echo %HIGH%%r%  ERROR:%END%%r% %*
IF /I [%2]==[powershell] echo %y%Consider install Management Framework at https://support.microsoft.com/en-us/help/968929/ %r% 1>&2
echo ==============================================================
echo.%END%
IF NOT DEFINED AUTOMATED pause
exit
goto :EOF
:::::::::::::::::::::::::::::::::::::::::::::::: technical functions


:select_versions
IF DEFINED DEBUG echo %HIGH%%c% %~0 %END%%c% %* %END%

:: manually re-validate each version:
set choice=n
set /P choice=Would you like to manually validate each version? [%HIGH%%y%%choice%%END%] 
IF /I NOT "%choice%"=="n" (
  for /L %%n in (1,1,%lastOption%) do (
    call set "install=%%install!product[%%n]!%%"
    IF "!install!"=="x" (
      call set "thisVersion=%%version!product[%%n]!%%"
      set /P version!product[%%n]!=version!product[%%n]!? [%HIGH%%m%!thisVersion!%END%] 
    )
  )
)

:: manually re-validate each product's download file:
IF %POPUP%==true (set havePOPUP=y) ELSE (set havePOPUP=n)
set /P havePOPUP=POPUP files list before download? [%HIGH%%y%%havePOPUP%%END%] 
IF /I "[%havePOPUP%]"=="[y]" (set POPUP=true) ELSE (set POPUP=false)

:: EXAMPLE: post-process some product's versions to shorten them for some reason:
:: PRODUCTx short versions are used in main download section for platform.ini files: !%%ax%!
for %%P in (BB CC PA) DO call set %%Px=%%%%Pversion:~0,1%%

:: EXAMPLE: special cases for some other products:
set SQL1x=%SQL1version%
set SQL2x=%SQL1version%
set AAx=%AAversion:~0,3%

echo.
goto :EOF



:detect_local_installs %*
IF DEFINED DEBUG echo %HIGH%%c% %~0 %END%%c% %* %END%

:: detect what's present to pre-check options
:: 3 different detection patterns: your needs, your choice!
for %%P in (AA BB CC PA AA1 CC1) DO (
  for /f "tokens=3 delims=-" %%v in ('dir /b install-%%P-*-product.ini 2^>NUL') DO (
    CALL set install%%P=x
    CALL set versionsFound%%P=%%v
  )
)
for %%P in (PA1 PA2 PA3 PA4) DO (
  IF EXIST %EXAMPLE_LocalFolder%\PA\%%P\ (
    CALL set install%%P=x
    CALL set versionsFound%%P=%%v
  )
)
for %%P in (SQL1 SQL2) DO (
  for /f "tokens=3 delims=-" %%v in ('dir /b install-%%P-*-platform.ini 2^>NUL') DO (
    CALL set install%%P=x
    CALL set versionsFound%%P=%%v
  )
)
goto :EOF



:: :winsize  winWidth  winHeight  bufWidth  bufHeight
:winsize
:: Console Resize values via PowerShell (changeable)
SET "_PSResize=100 54 100 9997"
IF NOT [%4]==[] SET "_PSResize=%1 %2 %3 %4"

:: Check for powershell via PATH variable
REM POWERSHELL "Exit" >NUL 2>&1 && SET "_PS=1"
REM IF NOT DEFINED _PS (ECHO No&do something) ELSE (ECHO Yes&do something)
 
:: PS-Console Resizing
REM IF DEFINED _PS CALL:_PS_ReSize %_PSRESIZE%
CALL :_PS_ReSize %_PSRESIZE%
goto :EOF

:: :_PS_Resize  winWidth  winHeight  bufWidth  bufHeight
:_PS_Resize
:: Mode sets buffer size-not window size
MODE %1,%2

:: resize
powershell -executionPolicy bypass -Command "&{$H=get-host;$W=$H.ui.rawui;$B=$W.buffersize;$B.width=%3;$B.height=%4;$W.buffersize=$B;}"
goto :EOF

:end
IF DEFINED DEBUG echo :end
echo %DATE% %TIME% %HIGH%%c% %~0 %END%%c% %* %END% ------- THE END

pause
del /f /q %LOGS%\%~n0.*.tmp.* 2>NUL

