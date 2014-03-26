#!/bin/sh


#######################  
#  INSTRUCTIONS:
# 
# navigate Terminal to a directory containing these things: 
#  * seqs.fna = demultiplexed fasta file
#  * map.txt  = QIIME-format metadata for all samples
#  * pickTheseOTUs.sh = this script
#
# Then call up macqiime BEFORE executing the script
# macqiime
# 
# Then execute the script and hope it goes well:
# ./pickTheseOTUs.sh
#
########################
# ---- This should not be necessary since "--enable_rev_strand_match" added
#   to pick_otus commands
#
# If sequences are reverse reads, turn them around before starting
#   check by blasting a few of them and look at blast alignment. 
#
# mkdir original
# mv seqs.fna original/revcomp_seqs.fna
# adjust_seq_orientation.py -i original/revcomp_seqs.fna -o seqs.fna -r
########################




########################
# Set some directory shortcuts
#   !! This assumes a default macqiime 1.8 install !! 

export QIIME_DIR=/macqiime
export reference_seqs=$QIIME_DIR/greengenes/gg_13_8_otus/rep_set/97_otus.fasta
export reference_tree=$QIIME_DIR/greengenes/gg_13_8_otus/trees/97_otus.tree
export reference_tax=$QIIME_DIR/greengenes/gg_13_8_otus/taxonomy/97_otu_taxonomy.txt

# If you're not sure, you should test those references by hand:
#   this should give you the top of each respective file.
#   if you get an error, rethink the reference pointers above. 
#   the export commands will not give an error if something goes wrong
#     you have to test them. 
#
# head $reference_seqs
# head $reference_tree
# head $reference_tax







#################
# The slow way
#   This results in a .biom file with taxonomy.
#
# pick_closed_reference_otus.py -i seqs.fna -r $reference_seqs -o otus_w_tax -t $reference_tax
#
# biom add-metadata -i otus_w_tax/otu_table.biom -o otu_table_metadata.biom -m map.txt
#################


#################
# The fast way
#   This is from tutorial: 
#     http://qiime.org/tutorials/chaining_otu_pickers.html
#   Except I've used closed ref uclust to suppress denovo clusters.

# directory to catch final otu table
mkdir otus

# group identical seqs - this is the timesaver
pick_otus.py --enable_rev_strand_match -m prefix_suffix -p 5000 -u 0 -i seqs.fna -o prefix_picked_otus
echo '\nfinished prefix picking...\n'

# pull representatives for otu picking
pick_rep_set.py -i prefix_picked_otus/seqs_otus.txt -f seqs.fna -o prefix_picked_otus/rep_set.fasta
echo 'finished picking prefix rep set...\n'
echo 'this next step will take a few minutes...\n'

# slow picking
pick_otus.py --enable_rev_strand_match -m uclust_ref -r $reference_seqs -C -i prefix_picked_otus/rep_set.fasta -o prefix_picked_otus/uclust_picked_otus/
echo 'finished uclust OTU picking...\n'

# put them back together
merge_otu_maps.py -i prefix_picked_otus/seqs_otus.txt,prefix_picked_otus/uclust_picked_otus/rep_set_otus.txt -o otus/otus.txt
echo 'finished merging maps...\n'

# Pick final rep set from greengenes sequences
pick_rep_set.py -i otus/otus.txt -f seqs.fna -o otus/final_rep_set.fasta -r $reference_seqs  
echo 'finished picking final rep set...\n'

# then go through default qiime steps
assign_taxonomy.py -i otus/final_rep_set.fasta -r $reference_seqs -t $reference_tax
echo 'finished assigning taxonomy...\n'

# make otu table. 
make_otu_table.py -i otus/otus.txt -t uclust_assigned_taxonomy/final_rep_set_tax_assignments.txt -o otu_table.biom
echo 'finished making OTU table...\n'

# add metadata to mapping file
mkdir otu_table_metadata
biom add-metadata -i otu_table.biom -o otu_table_metadata/otu_table_metadata.biom -m map.txt
echo 'finished adding metadata to OTU table...\n'

# summarize the final otu table. This uses the metadata version. 
biom summarize-table -i otu_table_metadata/otu_table_metadata.biom -o otu_table_metadata/otu_table_stats.txt
echo 'this many sequences were in the original "seq.fna" file:'
grep -c '>' seqs.fna
echo '\nthese stats can be found in "otu_table_metadata/otu_table_stats.txt":\n'
echo '-----------------------------\n'
head -n 1000 otu_table_metadata/otu_table_stats.txt
echo '\n-----------------------------\n'
