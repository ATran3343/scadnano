#TODO: don't know how to prevent this check from printing error message to the screen in case pub isn't found
if type pub > /dev/null; then
  PUB=pub
  echo "Using pub as dart pub command"
else 
  # on Windows the pub command is called pub.bat
  PUB=pub.bat
  echo "Using pub.bat as dart pub command"
fi

if [ "$1" == "--debug" ] || [ "$1" == "-d" ]; then
  $PUB run build_runner test -- -P debug
elif [ "$1" == "--test" ] || [ "$1" == "-t" ]; then
  $PUB run build_runner test -- $2
elif [ "$1" == "--td" ] || [ "$1" == "--dt" ]; then
  $PUB run build_runner test -- $2 -P debug
else
  $PUB run build_runner test
fi