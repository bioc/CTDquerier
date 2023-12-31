#' Function to query CTDbase using disease terminology
#'
#' This function checks for CTDbase disease vocabulary and query CTDbase
#' for each one, downloading disease-gene interactions, chemicals
#' interactions, associated diseases, associated KEGG pathways and
#' associated GO terms.
#'
#' @param terms Character vector with the diseases used in the query.
#' @param ask (default \code{TRUE}) If \code{TRUE} it asks the the persistent
#' location must be used to save the vocabulary if it was not downloaded
#' previously.
#' @param verbose (default \code{FALSE}) If set to \code{TRUE} is shows relevant
#' information of each step.
#' @return An object of class \code{\link{CTDdata}}.
#' @examples
#' # Example in a tryCatch, since we are performing a connection to a server we might
#' # get a refused connection due to a server rejection. Evaluate the recieved HTTP 
#' # message to understand if the server is not available or if your IP adress is temporarly restricted
#' rst <- tryCatch({query_ctd_dise( terms = "Asthma", verbose = TRUE )}, error = function(w){NULL})
#' @export query_ctd_dise
query_ctd_dise <- function( terms, ask = TRUE, verbose = FALSE ) {
  ## SETUP
  if( !download_ctd_dise( verbose, ask ) ) {
    return( create_empty_data( terms ) )
  }
  if( verbose ) message( "Loading disease vocabulary." )
  tbl <- load_ctd_dise( verbose )
  ## //

  ## VALIDATE INPUT DISEASES
  terms <- toupper( terms )
  keep <- S4Vectors::DataFrame( DiseaseName = "", DiseaseID = "" )
  disc <- character()
  for( ii in seq_len(length(terms)) ) {
    if( terms[ ii ] %in% tbl$DiseaseName ) {
      keep <- rbind( keep, tbl[ tbl$DiseaseName == terms[ ii ] , c( "DiseaseName", "DiseaseID" ) ] )
    } else {
      disc <- c(disc, terms[ ii ])
    }
  }
  keep <- keep[ -1, ]

  if( length( disc ) != 0 ) {
    warning( length( disc ) , "/", length( terms ), " terms were discarted." )
  }
  ## //

  disease_gene_interactions <- prepare_ctd_disease( "disease_gene_interactions" )
  disease_kegg <- prepare_ctd_disease( "disease_kegg" )
  disease_chemical_interaction <- prepare_ctd_disease( "disease_chemical_interaction" )
  for( ii in seq( nrow( keep ) ) ) {
    if( verbose ) {
      message( "Staring query for disease '", keep[ ii, 1 ], "' ( ", keep[ ii, 2 ], " )" )
    }

    ## PREPARE URLs
    url_idx <- get_ctd_url(
      index    = "disease_gene",
      term     = keep[ ii, 2 ],
      category = "disease"
    )
    url_kegg <- get_ctd_url(
      index    = "disease_kegg",
      term     = keep[ ii, 2 ],
      category = "disease"
    )
    url_chemical <- get_ctd_url(
      index    = "disease_chemical",
      term     = keep[ ii, 2 ],
      category = "disease"
    )
    ## //

    # DOWNLOAD CONTENT
    if( verbose ) {
      message( " . Downloading 'disease-gene interaction' table." )
    }
    tmp <- download_url( url = url_idx )
    if( nrow( tmp ) > 0 ) {
        #tmp$GeneSymbol <- keep[ ii, 1 ]
        #tmp$GeneID <- keep[ ii, 2 ]
        disease_gene_interactions <- rbind( disease_gene_interactions, S4Vectors::DataFrame(tmp) )
    } else if( verbose ) {
        message(" . . No 'disease-chemical interation' table available for ", keep[ ii, 1 ], "' ( ", keep[ ii, 2 ], " )" )
    }
    if( verbose ) {
      message( " . Downloading 'disease-chemical interation' table." )
    }
    tmp <- download_url( url = url_chemical )
    if( nrow( tmp ) > 0 ) {
      #tmp$GeneSymbol <- keep[ ii, 1 ]
      #tmp$GeneID <- keep[ ii, 2 ]
      disease_chemical_interaction <- rbind( disease_chemical_interaction, S4Vectors::DataFrame(tmp) )
    } else if( verbose ) {
      message(" . . No 'disease-chemical interation' table available for ", keep[ ii, 1 ], "' ( ", keep[ ii, 2 ], " )" )
    }
    if( verbose ) {
      message( " . Downloading 'KEGG pathways' table." )
    }
    tmp <- download_url( url = url_kegg )
    if( nrow( tmp ) > 0 ) {
      #tmp$GeneSymbol <- keep[ ii, 1 ]
      #tmp$GeneID <- keep[ ii, 2 ]
      disease_kegg <- rbind( disease_kegg, S4Vectors::DataFrame(tmp) )
    } else if( verbose ) {
      message(" . . No 'KEGG pathways' table available for ", keep[ ii, 1 ], "' ( ", keep[ ii, 2 ], " )" )
    }
    # //
  }
  rm( tmp, ii )

  new( "CTDdata",
       type                   = "DISEASE",
       timestamp              = as.character( Sys.time() ),
       terms                  = S4Vectors::DataFrame( keep ),
       losts                  = disc,
       gene_interactions      = disease_gene_interactions,
       chemicals_interactions = disease_chemical_interaction,
       diseases               = S4Vectors::DataFrame(),
       gene_gene_interactions = S4Vectors::DataFrame(),
       kegg                   = disease_kegg,
       go                     = S4Vectors::DataFrame()
  )
}


prepare_ctd_disease <- function( set ) {
  if( set == "disease_gene_interactions" ) {
    gene_interactions <- rbind( 1:8 )
    colnames( gene_interactions ) <- c( "Gene Symbol", "Gene ID", "Disease Name", "Disease ID", "Direct Evidence", "Inference Network", "Inference Score", "Reference Count" )
    return( S4Vectors::DataFrame(gene_interactions[ -1, ] ) )
  }

  if( set == "disease_kegg" )  {
    gene_kegg <- rbind( 1:5 )
    colnames( gene_kegg ) <- c( "Disease Name", "Disease ID", "Pathway", "Pathway ID", "Association inferred via" )
    return( S4Vectors::DataFrame( gene_kegg[ -1, ] ) )
  }

  if( set == "disease_chemical_interaction" ) {
    disease_chemical_interaction <- rbind( 1:9 )
    colnames( disease_chemical_interaction ) <- c( "Chemical Name", "Chemical ID", "CAS RN", "Disease Name", "Disease ID", "Direct Evidence", "Inference Network", "Inference Score", "Reference Count" )
    return( S4Vectors::DataFrame( disease_chemical_interaction[ -1, ] ) )
  }

  stop( "[INTERNAL] Invalid selected set." )
}
