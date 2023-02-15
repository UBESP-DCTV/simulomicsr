# ARCHS4 is a collection of thounsands (>600k now) RNAseq data
# organized in H5 format.
# You can download it from https://maayanlab.cloud/archs4/download.html
# The one used for this package is currently 'human_matrixv2.1.2.h5' (~26GB)

# c'è anche la versione mouse che potremmo usare

BiocManager::install('rhdf5')
library('rhdf5')

# get dimensions and structure of the file
# useful to see what data you can get
h5ls('C:/archs4_gene_human_v2.1.2.h5')

# Gene names to use as annotation
genes_names <- h5read('C:/archs4_gene_human_v2.1.2.h5', 
                                    'meta/genes')[["gene_symbol"]]

# The actual expression data.
### WARNING!###
# Do not try do get them all in a single step. Use `index` to subset the file
# the first argument are the rows (genes) and the second the expression datasets
seq_db <- as.data.frame(h5read('C:/archs4_gene_human_v2.1.2.h5',
                  
                  'data/expression', index = list(1:62548, c(1:50))))

# add the genes to the dataset
seq_db$genes <- genes_names

# if you need you can get the metadata for every single file-run used
samples <- h5read('C:/archs4_gene_human_v2.1.2.h5', 
                  'meta/samples')




                  