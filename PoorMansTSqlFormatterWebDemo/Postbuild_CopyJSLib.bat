REM Copy compiled JS libraries from another project

IF NOT EXIST %2JSLibReference\%3\ mkdir %2JSLibReference\%3\
copy %1PoorMansTSqlFormatterJSLib\bin\%3\bridge\PoorMansTSqlFormatterJS.min.js %2JSLibReference\%3\
IF %ERRORLEVEL% NEQ 0 GOTO END
copy %1PoorMansTSqlFormatterJSLib\bin\%3\bridge\PoorMansTSqlFormatterJS.js %2JSLibReference\%3\
IF %ERRORLEVEL% NEQ 0 GOTO END

:END