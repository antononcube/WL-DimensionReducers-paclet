(* ::Package:: *)

(* :Title: IndependentComponentAnalysis *)
(* :Context: IndependentComponentAnalysis` *)
(* :Author: Anton Antonov *)
(* :Date: 2016-05-14 *)

(* :Package Version: 0.8 *)
(* :Mathematica Version: 10.4.1 *)
(* :Copyright: (c) 2016 Anton Antonov *)
(* :Keywords: Independent Component Analysis, ICA, FastICA, matrix factorization *)
(* :Discussion: *)

(* Version 0.8 *)
(*

    This package provides functions for performing Independent Component Analysis (ICA) over matrices.
    The function IndependentComponentAnalysis is intended to be the front of different algorithms for ICA.

    ICA can be seen as a dimension reduction or matrix factorization technique. Because of that the function
    IndependentComponentAnalysis returns a pair of matrices the product of which should approximate the first
    argument. This is different from the result of R's FastICA. Because of this a separate function, FastICA,
    is provided.

    The first version of this package implements the algorithm FastICA.
    The implementation follows closely the code in the R library FastICA.R, see

      https://cran.r-project.org/web/packages/fastICA/index.html ,

    and the article

      A. Hyvarinen and E. Oja (2000) Independent Component Analysis: Algorithms and Applications,
      Neural Networks, 13(4-5):411-430 .

    *********************
    Usage example
    **********************

    In the code below the columns of S have the independent components, the rows are samples.
    The matrix A provides linear mixing. The matrix M has the mixed signals.
    The independent component analysis functions should be fairly fast.

    (* Signal functions *)
    Clear[s1, s2, s3]
    s1[t_] := Sin[600 \[Pi] t/10000 + 6*Cos[120 \[Pi] t/10000]] + 1.2
    s2[t_] := Sin[\[Pi] t/10] + 1.2
    s3[t_?NumericQ] := (((QuotientRemainder[t, 23][[2]] - 11)/9)^5 + 2.8)/2 + 0.2

    (* Mixing matrix *)
    A = {{0.44, 0.2, 0.31}, {0.45, 0.8, 0.23}, {0.12, 0.32, 0.71}};

    (* Signals matrix *)
    nSize = 600;
    S = Table[{s1[t], s2[t], s3[t]}, {t, 0, nSize, 0.5}];
    Dimensions[S]
    (* {1201, 3} *)

    (* Mixed signals matrix *)
    M = S.A;
    Grid[{Map[ListLinePlot[#, PlotRange -> All, ImageSize -> 250] &, Transpose@S]}]

    (* Mixed signals *)
    Grid[{Map[ListLinePlot[#, PlotRange -> All, ImageSize -> 250] &, Transpose@M]}]

    (* ICA function call *)
    AbsoluteTiming[
      res = IndependentComponentAnalysis[M, 3];
    ]
    (* {0.010782, Null} *)

    (* Approximation norm *)
    Norm[M - Dot @@ res]
    (* 5.25579*10^-14 *)

    (* Visualize the source signals result *)
    ListLinePlot[#, ImageSize -> Medium] & /@ Transpose[res[[1]]]


TODO:
    1. Implement symmetric FastICA using logcosh/exp/etc approx. to neg-entropy function.
    2. Implement NNMF based method for ICA.
    3. Handling high precision matrices.

    This file was created by Mathematica Plugin for IntelliJ IDEA.
*)

BeginPackage["AntonAntonov`DimensionReducers`IndependentComponentAnalysis`"];

Needs["AntonAntonov`DimensionReducers`"];

(*IndependentComponentAnalysis::usage = "IndependentComponentsAnalysis[ X_?MatrixQ, k_Integer ] \*)
(*independent components analysis (factorization) over the matrix X for k number of components.";*)

(*FastICA::usage = "FastICA[X_?MatrixQ, k_Integer, opts___] applies the algorithm FastICA to X in order to find \*)
(*k independent components. Returns an association with the corresponding matrix names as keys.";*)

Begin["`Private`"];

Clear[IndependentComponentAnalysis];

IndependentComponentAnalysis::nargs =
    "A numeric matrix and a positive integer are expected as a first and a second argument respectively.";
IndependentComponentAnalysis::nomat =
    "A numeric matrix is expected as a first argument.";
IndependentComponentAnalysis::noint =
    "A positive integer no greater than the number of columns of the matrix is expected as a second argument.";
IndependentComponentAnalysis::unmat =
    "The un-mixing matrix option value should be Automatic or a square matrix corresponding to the number of components.";
IndependentComponentAnalysis::nnum = "Non-numerical internal result was obtained.";

FastICA::nomat = "A matrix is expected as a first argument.";
FastICA::noint =
    "A positive integer no greater than the number of columns of the matrix is expected as a second argument.";
FastICA::unmat =
    "The un-mixing matrix option value should be Automatic or a square matrix corresponding to the number of components.";

Options[IndependentComponentAnalysis] = {
  MaxSteps -> 200, PrecisionGoal -> 6,
  "NonGaussianityFunction" -> Automatic, "NegEntropyFactor" -> 1,
  "InitialUnmixingMartix" -> Automatic, "RowNorm" -> False};

IndependentComponentAnalysis[X_, k_, opts : OptionsPattern[]] :=
    Block[{nonGaussFunc, alpha, rowNormQ, unmixMatSpec, maxSteps, pgoal, res},

      If[! MatrixQ[X, NumericQ],
        ResourceFunction["ResourceFunctionMessage"][IndependentComponentAnalysis::nomat];
        Return[$Failed]
      ];

      If[! IntegerQ[k] || ! (1 <= k <= Dimensions[X][[2]]),
        ResourceFunction["ResourceFunctionMessage"][IndependentComponentAnalysis::noint];
        Return[$Failed]
      ];

      res = FastICA[X, k, "RFastICAResult" -> False, opts];

      If[AssociationQ[res], {res["S"], res["A"]}, res]
    ];

IndependentComponentAnalysis[___] :=
    Block[{},
      ResourceFunction["ResourceFunctionMessage"][IndependentComponentAnalysis::nargs];
      Return[$Failed]
    ];


Clear[FastICA];

Options[FastICA] = {
  "NonGaussianityFunction" -> Automatic,
  "NegEntropyFactor" -> 1, "InitialUnmixingMatrix" -> Automatic,
  "RowNorm" -> False, MaxSteps -> 200, PrecisionGoal -> 6,
  "RFastICAResult" -> True};

FastICA[X_?MatrixQ, k_Integer, opts : OptionsPattern[]] :=
    Block[{nonGaussFunc, alpha, rowNormQ, unmixMatSpec, maxSteps, pgoal, n, m,
      ncomp = k, wInitMat, V, XU, XD, XV, XD1, K, X1, W, aMat, wMat, S, A},

      nonGaussFunc = OptionValue[FastICA, "NonGaussianityFunction"];
      alpha = OptionValue[FastICA, "NegEntropyFactor"];
      rowNormQ = OptionValue[FastICA, "RowNorm"];
      unmixMatSpec = OptionValue[FastICA, "InitialUnmixingMatrix"];
      maxSteps = OptionValue[FastICA, MaxSteps];
      pgoal = OptionValue[FastICA, PrecisionGoal];

      If[! MatrixQ[X],
        ResourceFunction["ResourceFunctionMessage"][
          IndependentComponentAnalysis::nomat];
        Return[$Failed]
      ];

      If[! IntegerQ[ncomp] || ! (1 <= k <= Dimensions[X][[2]]),
        ResourceFunction["ResourceFunctionMessage"][
          IndependentComponentAnalysis::noint];
        Return[$Failed]
      ];

      If[TrueQ[nonGaussFunc === Automatic],
        nonGaussFunc = Log[Cosh[#]] &;
      ];

      Which[
        TrueQ[unmixMatSpec === Automatic],
        wInitMat =
            Partition[RandomVariate[NormalDistribution[], ncomp^2], ncomp],

        TrueQ[MatrixQ[unmixMatSpec] && Dimensions[unmixMatSpec] == {ncomp, ncomp}],
        wInitMat = unmixMatSpec,

        True,
        ResourceFunction["ResourceFunctionMessage"][
          IndependentComponentAnalysis::unmat];
        Return[$Failed]
      ];

      {n, m} = Dimensions[X];

      (*Centering*)
      If[rowNormQ,
        X1 = Standardize[#, Mean, StandardDeviation] & /@ Transpose[X],
        X1 = Standardize[#, Mean, 1 &] & /@ Transpose[X]
      ];

      If[TrueQ[Head[X] === SparseArray],
        X1 = SparseArray[X1]
      ];

      (*Whitening*)
      V = X1 . Transpose[X1] / n;
      {XU, XD, XV} = SingularValueDecomposition[V];
      XD1 = DiagonalMatrix[1 / Sqrt[Map[If[# < 10^-12, 1, #] &, Diagonal[XD]]]];
      K = XD1 . Transpose[XU];
      K = K[[1 ;; ncomp, All]];

      If[TrueQ[Head[X] === SparseArray],
        K = SparseArray[K]
      ];

      (*X1=K.X1;*)
      aMat =
          ICADeflation[K . X1, ncomp, wInitMat, nonGaussFunc, pgoal, alpha,
            maxSteps];
      If[TrueQ[aMat === $Failed],
        Return[$Failed]
      ];

      If[TrueQ[Head[X] === SparseArray], aMat = SparseArray[aMat]];

      K = Transpose[K];
      aMat = Transpose[aMat];
      X1 = Transpose[X1];
      wMat = K . aMat;
      A = Transpose[wMat . Inverse[Transpose[wMat] . wMat]];

      If[OptionValue[FastICA, "RFastICAResult"],
        S = X1 . wMat;
        AssociationThread[{"X", "K", "W", "A", "S"} -> {X1, K, aMat, A, S}],
        (*ELSE*)
        S = X . wMat;
        AssociationThread[{"K", "W", "A", "S"} -> {K, aMat, A, S}]
      ]
    ];

Clear[ICADeflation];
ICADeflation[X_?MatrixQ, ncomp_Integer, wInitMat_?MatrixQ, func_,
  pgoal_?NumberQ, alpha_?NumberQ, maxSteps_Integer] :=
    Block[{n, m, w, w1, W, g, gp, t, k, nStep = 0, wx, gwx, gwxMat, xgwxMat,
      gpwx, v1, v2, wd},

      {n, m} = Dimensions[X];
      g = func';
      gp = func'';

      W = ConstantArray[0, {ncomp, ncomp}];

      Do[w = wInitMat[[i, All]];
      If[i > 1, t = ConstantArray[0, Length[w]];
      Do[
        k = w . W[[j, All]];
        t = t + k * W[[j, All]];
        , {j, 1, i - 1}
      ];
      w = w - t;
      ];

      w = w / Norm[w];
      wd = 1000;

      While[wd > 10^-pgoal && nStep < maxSteps,
        nStep++;
        wx = w . X;
        gwx = g[alpha * wx];
        If[! VectorQ[gwx, NumericQ],
          ResourceFunction["ResourceFunctionMessage"][
            IndependentComponentAnalysis::nnum];
          Return[$Failed]
        ];
        gwxMat = Table[gwx, {ncomp}];
        xgwxMat = X * gwxMat;
        v1 = Mean /@ xgwxMat;
        gpwx = alpha * g[alpha * wx];
        v2 = Mean[gpwx] * w;
        w1 = v1 - v2;
        If[i > 1, t = ConstantArray[0, Length[w1]];
        Do[k = w1 . W[[j, All]];
        t = t + k * W[[j, All]];, {j, 1, i - 1}];
        w1 = w1 - t;
        ];
        w1 = w1 / Norm[w1];
        wd = Abs[Abs[w . w1] - 1];
        w = w1;
      ];(*While*)

      W[[i, All]] = w;
        , {i, 1, ncomp}
      ];(*Do*)

      W
    ];

End[]; (* `Private` *)

EndPackage[]
