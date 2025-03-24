# Digital Electronic System Design  
**Politecnico di Milano (2024-2025)**  

## 📖 Overview  
Welcome to the **Digital Electronic System Design Laboratory** repository!  
This repository contains VHDL projects and exercises from the course **Digital Electronic System Design** at **Politecnico di Milano** *(Course Code: 054083)*.  

The course focuses on:  
- **FPGA-based digital design**  
- **VHDL simulation, synthesis, and implementation**  

## 🛠️ Tools & Hardware  
- **Software**:  
  - [Xilinx Vivado 2020.2](https://www.xilinx.com/products/design-tools/vivado.html) *(WebPack Edition)*  
- **Hardware**:  
  - [Digilent Basys 3](https://digilent.com/shop/basys-3-artix-7-fpga-trainer-board-recommended-for-introductory-users/)  
    - FPGA: *Xilinx Artix-7* (**XC7A35T-1CPG236C**)  

## 🎯 Course Goals  
- Develop practical skills for **FPGA-based digital system design**  
- Implement and test **VHDL architectures** using Vivado and Basys 3  
- Learn about **FPGA timing, power, I/O, and memory management**  

## 📂 Repository Structure
- `LABx/`
  - `src/`: VHDL source files  
  - `sim/`: Simulation files  
  - `cons/`: Constraint files  
  - `vivado/`: Vivado project files 

## 🚀 Getting Started  

### Clone the Repository  
To get started with this project, follow these steps:  

1. Open a terminal (e.g., Command Prompt or PowerShell) on your Windows machine.
2. Clone the repository using Git:  
   ```cmd
   git clone https://git.cdtech.duckdns.org/PickleRick/DESD.git
   ```
   This will create a folder named `DESD`.  
3. Open the folder `\DESD` in [Visual Studio Code](https://code.visualstudio.com/).  

> [!Warning]  
> The folder structure in the repository may not match the Vivado project structure.  
> If you encounter issues with missing or mismatched files in Vivado, refer to the [Replacing Files in Vivado](#replacing-files-in-vivado) section to update the project with the correct files.

### Install VHDL Extension  
To work with VHDL files in Visual Studio Code, install the **VHDL LS** extension:  

1. Open Visual Studio Code.  
2. Go to the Extensions view by clicking on the Extensions icon in the Activity Bar on the side of the window or pressing `Ctrl+Shift+X`.  
3. Search for **VHDL LS** in the Extensions Marketplace.  
4. Click **Install** on the extension by [Håkon Bohlin](https://marketplace.visualstudio.com/items?itemName=hbohlin.vhdl-ls).  
5. Restart Visual Studio Code to activate the extension.  

### Open Projects in Vivado  
To open and work with the Vivado projects included in this repository:  

1. Launch **Xilinx Vivado 2020.2**.  
2. Click on **Open Project** in the Vivado start screen.  
3. Navigate to the desired project directory (e.g., `LABx/vivado/project_folder/`) and select the `.xpr` file.  
4. Once the project is loaded, you can explore the design, run simulations, or synthesize the project.  

#### Replacing Files in Vivado  
If the folder structure in the repository does not match the Vivado project structure:  

1. Open the Vivado project as described above.  
2. In the **Sources** tab, right-click on the file you want to replace and select **Replace File**.  
3. Navigate to the correct file in the repository (e.g., `LABx/src/`) and select it.  
4. Ensure the file is added to the correct hierarchy (e.g., as a design source or constraint file).  
5. Save the project and re-run synthesis or simulation as needed.  

By following these steps, you can ensure that the Vivado project is correctly configured and up-to-date with the repository files.

## 📬 Contact  
For any questions or issues open an issue in this repository.