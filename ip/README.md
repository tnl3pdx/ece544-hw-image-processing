# IP Repository

clk_wiz_0 contains the configuration file to setup the clock wizard for the project.

To import IP for this project, add the contents of ip_repo from the mbc_wb repository and place it in this directory. Add this folder as a repository path for the project under Vivado/Settings/IP/Repository. Remove the project's default IP reposity path to prevent any collisions between identical IP. The folder structure should look like this:

- ip/
  - clk_wiz_0/
  - ip_repo/
    - axilite2wbsp/
    - vivado-library/