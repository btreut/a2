MODULE PDFExample; (** AUTHOR "TF"; PURPOSE "Shows the use of the PDF creator library"; *)

IMPORT
	WMGraphics, PDF;

PROCEDURE PolyLine*;
VAR c : PDF.PDFCanvas;
	pdfDoc : PDF.PDFCreator;
	r : ARRAY 4 OF WMGraphics.Point2d;
BEGIN
	NEW(pdfDoc);
	c := pdfDoc.NewPage(PDF.PageA4, FALSE, PDF.Unitmm100);
	r[0].x := 50 * 100; r[0].y := 100 * 100;
	r[1].x := 200 * 100; r[1].y := 100 * 100;
	r[2].x := 200 * 100; r[2].y := 200 * 100;
	r[3].x := 100 * 100; r[3].y := 200 * 100;
	c.PolyLine(r, 4, TRUE, LONGINT(0FF0000FFH), WMGraphics.ModeCopy);
	pdfDoc.Store("Test.pdf");
END PolyLine;

PROCEDURE FillPoly*;
VAR c : PDF.PDFCanvas;
	pdfDoc : PDF.PDFCreator;
	r : ARRAY 4 OF WMGraphics.Point2d;
BEGIN
	NEW(pdfDoc);
	c := pdfDoc.NewPage(PDF.PageA4, FALSE, PDF.Unitmm100);
	r[0].x := 150 * 100; r[0].y := 100 * 100;
	r[1].x := 200 * 100; r[1].y := 100 * 100;
	r[2].x := 200 * 100; r[2].y := 200 * 100;
	r[3].x := 100 * 100; r[3].y := 200 * 100;
	c.FillPoly(r, 4, 0FFFFH, WMGraphics.ModeCopy);
	pdfDoc.Store("Test.pdf");
END FillPoly;

PROCEDURE Text*;
VAR c : PDF.PDFCanvas;
	pdfDoc : PDF.PDFCreator;
BEGIN
	NEW(pdfDoc);
	c := pdfDoc.NewPage(PDF.PageA4, FALSE, PDF.Unitmm100);
	c.PDFSetFont("Oberon", 100*12, {});
	c.DrawString(1000, 1000, "Hello World");
	pdfDoc.Store("Test.pdf");
END Text;

END PDFExample.

SystemTools.Free PDF ~
SystemTools.Free PDFExample ~
PDFExample.PolyLine~
PDFExample.FillPoly~
PDFExample.Text~

Notepad.Open Test.pdf ~
