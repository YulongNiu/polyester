#' write sequencing reads to disk
#'
#' given a DNAStringSet representing simulated sequencing reads, write FASTA
#'   files to disk representing the simulated reads.
#' @param reads DNAStringSet representing sequencing reads
#' @param fname file path/prefix specifying where sequencing reads should be
#'   written. Should not contain ".fasta" (this is appended automatically).
#' @param readlen maximum length of the reads in \code{reads}.
#' @param paired If \code{TRUE}, reads are assumed to be in pairs: i.e., read 1
#'   and read 2 in \code{reads} are the left and right mate (respectively) of a
#'   read pair; same with read 3 and read 4, etc. The odd-numbered reads are
#'   written to \code{fname_1.fasta} and the even-numbered
#'   reads are written to \code{fname_2.fasta}. If \code{FALSE}, reads are
#'   assumed to be single-end and just one file, \code{fname.fasta}, is written.
#' @param gzip If \code{TRUE}, gzip the output fasta files.
#' @export
#' @param offset An integer number greater or equal to 1 to start assigning 
#' read numbers at.
#' @param shuffle If \code{TRUE}, shuffles the reads before writing them to file.
#' @details The \code{\link{get_reads}} function returns a DNAStringSet object
#'   representing sequencing reads that can be directly passed to
#'   \code{write_reads}. If output other than that from \code{get_reads} is used
#'   and \code{paired} is \code{TRUE}, make sure \code{reads} is ordered
#'   properly (i.e., that mate pairs appear together and that the left mate
#'   appears first).
#' @return No return, but FASTA file(s) containing the sequences in \code{reads}
#'   are written to \code{fname.fasta} (if \code{paired} is FALSE) or
#'   \code{fname_1.fasta} and \code{fname_2.fasta} if \code{paired} is TRUE.
#' @seealso \code{\link{get_reads}}
#' @examples
#'   library(Biostrings)
#'   data(srPhiX174) # pretend srPhiX174 represents a DNAStringSet of *reads*
#'   readlen = unique(width(srPhiX174)) #35
#'   write_reads(srPhiX174, fname='./srPhiX174', readlen=readlen, paired=FALSE,
#'       gzip=FALSE)
#'
#' ## If the file is too big, you can subset it and write it in chunks.
#' ## Here we split our 'reads' into two chunks and save them to the same file.
#' write_reads(srPhiX174[1:100], fname='./srPhiX174-offset', readlen=readlen, 
#'    paired=FALSE, gzip=FALSE, offset = 1L)
#' write_reads(srPhiX174[101:length(srPhiX174)], fname='./srPhiX174-offset', 
#'    readlen=readlen, paired=FALSE, gzip=FALSE, offset = 101L)
#'
#' ## We can verify that we get the same results
#' srPhi <- readDNAStringSet('./srPhiX174.fasta')
#' srPhiOffset <- readDNAStringSet('./srPhiX174-offset.fasta')
#' identical(srPhi, srPhiOffset)
#'
write_reads = function(reads, fname, readlen, paired=TRUE, gzip, offset=1L,
                       shuffle=FALSE){
    compress = ifelse(is.null(gzip), FALSE, gzip)
    stopifnot(is.integer(offset) & offset >= 1)
    append = ifelse(offset == 1, FALSE, TRUE)
    if(is.null(names(reads))) names(reads) <- rep("", length(reads))
    if(paired){
        lefts = reads[seq(1, length(reads), by=2)]
        rights = reads[seq(2, length(reads), by=2)]
        readnumbers = offset:(length(lefts) + offset - 1)
        names(lefts) = sprintf('read%d/%s', readnumbers, names(lefts))
        names(rights) = sprintf('read%d/%s', readnumbers, names(rights))
        left_filepath = sprintf('%s_1.fasta', fname)
        right_filepath = sprintf('%s_2.fasta', fname)
        if(shuffle) {
          # store the random seed
          old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
          old_seed <- .Random.seed
          shuffled_rows <- sample(length(lefts))
          lefts <- lefts[shuffled_rows]
          rights <- rights[shuffled_rows]
          # restoring the seed allows shuffled & unshuffled runs to be identical
          assign(".Random.seed", old_seed, envir = .GlobalEnv)
        }
        if(compress){
            left_filepath = sprintf('%s.gz', left_filepath)
            right_filepath = sprintf('%s.gz', right_filepath)
        }

        ##~~~~~~~~~~~~~~add qualities~~~~~~~~~~~~~~~~~~~~~~~~
        mcols(lefts)$qualities <- GenerateQ(width(lefts), length(lefts))
        mcols(rights)$qualities <- GenerateQ(width(rights), length(rights))
        ##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        writeXStringSet(lefts, filepath=left_filepath,
            format="fastq", compress=compress, append=append)
        writeXStringSet(rights, filepath=right_filepath,
            format="fastq", compress=compress, append=append)
    }else{
        outf = sprintf('%s.fasta', fname)
        if(compress){
            outf = sprintf('%s.gz', outf)
        }
        readnumbers = offset:(length(reads) + offset - 1)
        names(reads) = sprintf('read%d/%s', readnumbers, names(reads))
        if (shuffle) {
          old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
          reads <- reads[sample(length(reads))]
          assign(".Random.seed", old_seed, envir = .GlobalEnv)
        }

        ##~~~~~~~~~~~~~~add qualities~~~~~~~~~~~~~~~~~~~~~~~~
        mcols(reads)$qualities <- GenerateQ(width(reads), length(reads))
        ##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        writeXStringSet(reads, filepath=outf, format="fastq", compress=compress, append=append)
    }
}






##' Generate quality
##'
##' Randomly generate read qualities.
##'
##' @title Random quality generator
##' @param len An \code{integer vector} represents the length of reads.
##' @param num An \code{integer} represents the reads number.
##' @return A \code{BStringSet}
##' @author Yulong Niu \email{yulong.niu@@hotmail.com}
##' @importFrom stringi stri_rand_strings
##' @importFrom Biostrings BStringSet
##' @importFrom magrittr %>%
##' @keywords internal
##'
GenerateQ <- function(len, num) {

  ## candidateQ <- '!"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~'

  quality <- stri_rand_strings(num, len, pattern = '[\\u0021-\\u007E]') %>%
    BStringSet

  return(quality)
}



## library(Biostrings)
## data(srPhiX174)
## readlen <- unique(width(srPhiX174))
## mcols(srPhiX174)$qualities <- GenerateQ(readlen, length(srPhiX174))
## names(srPhiX174) <- paste0('reads', 1:length(srPhiX174))
## writeXStringSet(srPhiX174, 'test.fq.gz', compress=TRUE, format = 'fastq')
