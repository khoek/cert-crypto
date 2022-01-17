check_pw_len () {
  if (($1 >= 4 && $1 <= 1023)); then
    :
  else
    echo "Password must be between 4 and 1023 characters (inclusive)"
    exit 1
  fi
}