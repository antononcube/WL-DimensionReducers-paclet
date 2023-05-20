(* ::Package:: *)

(* ::Section:: *)
(*Package Header*)


BeginPackage["AntonAntonov`DimensionReducers`"];

(*NNMF*)

NonNegativeMatrixFactorization::usage = "NonNegativeMatrixFactorization[V_?MatrixQ,k_Integer,opts] \
returns the pair of matrices {W,H} such that V = W H and \
the number of the columns of W and the number of rows of H are k. \
The method used is called Gradient Descent with Constrained Least Squares.";

GDCLS::usage = "Synonym of NonNegativeMatrixFactorization";

NonNegativeMatrixFactorizationGlobal::usage = "NonNegativeMatrixFactorizationGlobal[V_?MatrixQ,W_?MatrixQ,H_?MatrixQ,opts] \
continues the NNMF iterations over the matrices W and H \
in the execution context and returns {W,H} as a result.";

GDCLSGlobal::usage = "Synonym of NonNegativeMatrixFactorizationGlobal";

NormalizeMatrixProduct::usage = "NormalizeMatrixProduct[W_?MatrixQ,H_?MatrixQ] returns a pair of matrices {W1,H1} \
such that W1 H1 = W H and the norms of the columns of W1 are 1.";

LeftNormalizeMatrixProduct::usage = "Same as NormalizeMatrixProduct.";

RightNormalizeMatrixProduct::usage = "RightNormalizeMatrixProduct[W_?MatrixQ,H_?MatrixQ] returns a pair of matrices {W1,H1} \
such that W1 H1 = W H and the norms of the rows of H1 are 1.";

BasisVectorInterpretation::usage = "BasisVectorInterpretation[vec_?VectorQ,n_Integer,interpretationItems_List] \
takes the n largest coordinates of vec, finds the corresponding elements in interpretationItems, \
and returns a list of coordinate-item pairs.";

NearestWords::usage = "NearestWords[HNF, word, terms, stemmingRules, n] calculates a statistical thesaurus entry \
for a specified nearest function over the columns of a matrix of topics and a word.";

(*ICA*)

IndependentComponentAnalysis::usage = "IndependentComponentsAnalysis[ X_?MatrixQ, k_Integer ] \
independent components analysis (factorization) over the matrix X for k number of components.";

FastICA::usage = "FastICA[X_?MatrixQ, k_Integer, opts___] applies the algorithm FastICA to X in order to find \
k independent components. Returns an association with the corresponding matrix names as keys.";

Begin["`Private`"];

Needs["AntonAntonov`DimensionReducers`NonNegativeMatrixFactorization`"];
Needs["AntonAntonov`DimensionReducers`IndependentComponentAnalysis`"];

End[];
EndPackage[];