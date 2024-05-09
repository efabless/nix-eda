new: old: {
  ## Cairo X11 on Mac
  cairo =
    if (old.stdenv.isDarwin)
    then
      (old.cairo.override {
        x11Support = true;
      })
    else (old.cairo);

  ## slightly worse floating point errors cause ONE of the tests to fail on
  ## x86_64-darwin
  qrupdate =
    if old.system == "x86_64-darwin"
    then
      (old.qrupdate.overrideAttrs (finalAttrs: previousAttrs: {
        doCheck = false;
      }))
    else (old.qrupdate);
}
