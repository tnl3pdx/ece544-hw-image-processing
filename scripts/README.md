# TCL Script Directory
This folder will contain scripts for building the project and block design used in this project. 

## Vivado Project Setup
To instantiate the Vivado project for initial setup, do the following:

1. Create a vivado/ folder at the root of the repository.
2. Go into vivado/ and type in:
```bash
vivado -source ../scripts/build_proj.tcl
```
3. Vivado should then build an identical local .xpr project for your use. The embsys block design is not included with this script, so refer to the next section for block generation.
4. If changes are needed to be done to the project structure such as adding new files, do the following:
   1. Open ```build_proj.tcl``` and add to the file lists that contain file path data:
      1. Check the ```proc checkRequiredFiles```
      2. Check the sources_1 fileset under: ```# Set 'sources_1' fileset object```
      3. Check the sources_1 fileset file properties under: ```# Set 'sources_1' fileset file properties for remote files```


## Block Design Setup
To create/update the block design, do the following: 

1. Open your project in Vivado in your vivado/ folder.
2. Open the TCL Console and type the following command. Vivado should update your instance with the missing/updated block design.
   
```tcl
source ../scripts/gen_bd.tcl
```

4. If changes are made to the block design, ensure to type in the following command into the TCL Console. This should update the TCL script with your modifications to the block design.

```tcl
write_bd_tcl -force ../scripts/gen_bd.tcl
```

5. Push your changes to your branch.


Note: Ensure that you have the ip_repo folder added to your Vivado installation under Settings/IP/Repository to have axilite2wbsp available for the project script to pull from.