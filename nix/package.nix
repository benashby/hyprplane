{
  lib,
  stdenvNoCC,
  makeWrapper,
  bash,
  coreutils,
  jq,
  socat,
  hyprland ? null,
  withHyprland ? true,
}:

stdenvNoCC.mkDerivation {
  pname = "hyprplane";
  version = "0.1.0";

  src = ../.;

  nativeBuildInputs = [ makeWrapper ];

  makeFlags = [ "PREFIX=$(out)" ];

  postInstall = ''
    wrapProgram $out/bin/hyprplane \
      --prefix PATH ':' "${lib.makeBinPath (
        [ bash coreutils jq socat ]
        ++ lib.optional withHyprland hyprland
      )}"
    wrapProgram $out/bin/hyprplane-status \
      --prefix PATH ':' "${lib.makeBinPath [ coreutils jq ]}"
    wrapProgram $out/bin/hyprplane-workspaces \
      --prefix PATH ':' "${lib.makeBinPath (
        [ bash coreutils jq socat ]
        ++ lib.optional withHyprland hyprland
      )}"
  '';

  meta = with lib; {
    description = "Plane-level workspace grouping for Hyprland";
    homepage    = "https://github.com/benashby/hyprplane";
    license     = licenses.mit;
    platforms   = platforms.linux;
    mainProgram = "hyprplane";
  };
}
