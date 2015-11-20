#define WM_START (WM_USER+1)
#define WM_STOP (WM_USER+2)

#define IDB_BITMAP 998
#define IDC_BITMAP 999

#define IDM_D_Start 101
#define IDM_D_Attach 102
#define IDM_D_Stop 103
#define IDM_D_Exit 104

#define IDM_A_IGNORE 201
#define IDM_A_CONTINUE 202
#define IDM_A_EXCEPTION 203
#define IDM_A_STATE 204
#define IDM_A_TRAP 205
#define IDM_A_STACK 206
#define IDM_A_CLEARDEFAULT 207
#define IDM_A_TRAPDEFAULT 208
#define IDM_A_ALLSTACKS 209


#define	IDM_W_POS 2
#define IDM_W_ONTOP 301
#define IDM_W_TILE 302
#define IDM_W_CASCADE 303
#define IDM_W_ICONS 304
#define IDM_W_CALL 308
#define IDM_W_CCONSOLE 305
#define IDM_W_CEXCEPTION 306
#define IDM_W_CSYSTEM 307

#define IDM_H_About 401

#define IDM_WIN_CHILD 1000

#define IDD_Logo 1001
#define IDD_Ok 1002
#define IDD_Cancel 1003
#define IDD_ExePath 1004
#define IDD_State 1005
#define IDD_Stack 1006
#define IDD_ProcessID 1007
#define IDD_Open 1008
#define IDD_AllStacks 1009


#define ID_EDIT 0xCAC
#define GWW_HWNDEDIT 0

LRESULT CALLBACK WndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
LRESULT CALLBACK ChildWndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
BOOL CALLBACK AboutDlgProc(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam);
BOOL CALLBACK StartDlgProc(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam);
BOOL CALLBACK StateDlgProc(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam);
BOOL CALLBACK AttachDlgProc(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam);
DWORD WINAPI ThreadProc(LPVOID arg);
