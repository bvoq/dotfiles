GEM_PATH="$HOME/.gem/ruby"
if [ -d "$GEM_PATH" ]; then
  LARGEST_VERSION=$(\ls "$GEM_PATH" | sort -V | tail -n 1)
  if [ -d "$GEM_PATH/$LARGEST_VERSION/bin" ]; then
    export PATH="$PATH:$GEM_PATH/$LARGEST_VERSION/bin"
  fi
fi
