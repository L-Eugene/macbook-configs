# Host-specific settings: hostname and primary user account
{ username, hostname, ... }:

{
  networking.hostName = hostname;

  users.users.${username} = {
    home = "/Users/${username}";
  };
}
