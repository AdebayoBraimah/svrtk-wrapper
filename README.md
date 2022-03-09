# svrtk-wrapper
Bash wrapper scripts for use with SVRTK's super resolution command line tools

Command line tools and wrapper scripts designed to better faciliate use of [SVRTK](https://github.com/SVRTK/SVRTK.git)'s image super resolution software.

Essentially, a directory containing NIFTI files is globbed to perform super-resolution.

The steps of template image selection, and masking are performed in an automated fashion.

**NOTE**: 
* Template image selection is performed in a manner to ensure maximal brain coverage, and thus favors MR images with more voxels.
* The script `wrapper-recon.sh` is a wrapper script designed to be used on a LSF HPC located at CCHMC.

# Installation
The scripts are stand-alone wrapper scripts, and thus require no installation.

Moreover, the scripts can be downloaded by simply typing:

```bash
git clone https://github.com/AdebayoBraimah/svrtk-wrapper.git
```

## Dependences
The required dependencies that must be downloaded and compiled include:
* [`Python`](https://www.python.org/) v2.7+
* [`FSL`](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation) v6.0+
* [`SVRTK`](https://github.com/SVRTK/SVRTK) v1.0+

# Usage

Example usage:         

```bash
./recon-img.sh \
-i /path/to/image/directory/with/NIFTI/files \
-o /path/to/output/image/NIFTI/file \
-r 0.75 \
-g T2 \
--iterations 3
```

Typing `./recon-img.sh -h` provides the following help menu (shown below):

```

  Usage: recon-img.sh <required arguments> [optional arguments]

  Command line wrapper script intended for use with SVRTK's image super-resolution
  reconstruction executable. Designed to run on the UNIX command line.

  SVRTK can downloaded and compiled from here: https://github.com/SVRTK/SVRTK

  The required dependencies include:
    * SVRTK (mirtk reconstruct)
    * Python v2+
    * FSL

  Required Arguments

    -i, --img-dir     DIR     Input image directory of NIFTI files
    -o, --out         FILE    Output image name and directory path (must end with '.nii.gz')
    -r, --resolution  FLOAT   Output image isotropic image resolution (in mm)

  Optional Arguments

    -g, --glob-str    STR     Input image directory glob-string to select specific image contrast/modality
    --iterations      INT     Number of iterations for image reconstruction/super-resolution [default: 3]
    --no-cleanup              DO NOT perform clean-up [default: FALSE]
    -h, -help, --help         Prints usage to the command line
  
  Usage: recon-img.sh -i <DIR> -o <FILE> -r <FLOAT> [optional arguments]

  NOTE: Output image path MUST be absolute.
```

