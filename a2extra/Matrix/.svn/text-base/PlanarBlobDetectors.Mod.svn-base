MODULE PlanarBlobDetectors; (** AUTHOR "Patrick Hunziker"; PURPOSE "Blob detection"; *)
(*! alpha version - work in progress *)

(*see http://en.wikipedia.org/wiki/Blob_detection *)

IMPORT PlanarNabla, WMMatrix;

TYPE 
	ScalarField=PlanarNabla.ScalarField;

(** Laplacian of Gaussian is a classic blob detector. *)
(* Laplacian of Gaussian: apply after some weighted window function, e.g. a Gaussian or Spline Window, and sampling stragety. 
Support of Window Defines the Responsivity of the operator. Use sampling modes from PlanarNabla.Mod *)
(*! not yet finished: support width. Best used in a scale-space setup, i.e. multiresolution or multiple Gauss Support *)
PROCEDURE LaplacianOfGaussian*(CONST p:ScalarField; sampling:LONGINT):ScalarField;
BEGIN
	RETURN PlanarNabla.Laplacian(p, sampling);
END LaplacianOfGaussian;

(*to do: PROCEDURE DeterminantOfHessian() *)

(*to do: PROCEDURE HessianLaplace()b*)

(*to do: Lindeberg's watershed *)

(*to do PROCEDURE SplineBased..*)

(*to do: Scale-Space approach*)

PROCEDURE Test*;
VAR in: ScalarField; window: WMMatrix.Window;
BEGIN
	NEW(in,100,100);
	in[40..60,40..60]:=1;
	NEW(window, LaplacianOfGaussian(in, PlanarNabla.centered), "LOG 20"); window.AddWindow;
	in:=0; in[48..51, 48..51]:=1;
	NEW(window, LaplacianOfGaussian(in, PlanarNabla.centered), "LOG 4"); window.AddWindow;
	in:=0; in[49..50, 49..50]:=1;
	NEW(window, LaplacianOfGaussian(in, PlanarNabla.centered), "LOG 2"); window.AddWindow;
	
END Test;


END PlanarBlobDetectors.

PlanarBlobDetectors.Test
