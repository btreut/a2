#include <windows.h>
#include <richedit.h>
#include <stdio.h>
#include "Debug.h"

#define Title "Debugger for WinAos"

#define ModNext 4 // 0 + 4
#define ModName 8 // 4 +4
#define ModRefCnt 44 // 40 +4
#define ModSB 48 // 44 +4
#define ModData 80 //
#define ModCode 84 // 
#define ModRefs 92 // 
#define TypeTagName 20 // was 16
#define TypeTagMod 16 // was 48

#define MAX_THREADS 1024
#define MAX_OUTBUF 1024
#define MAX_FRAMES 64
#define MAX_VARS 32
#define MaxString 64
#define MaxArray 8

#define LONGINT long int
#define OCHAR unsigned char

static HANDLE hInst, hThread = INVALID_HANDLE_VALUE;
static HWND hwndMain, hwndMDIClient, hwndCon, hwndExc, hwndSys;
static OCHAR exePath[MAX_PATH] = "", workPath[MAX_PATH] = "", iniFile[MAX_PATH];
static OCHAR module[MaxString];
static PROCESS_INFORMATION proc;
static STARTUPINFO start;
static DWORD threadId, debugAction;
static char outBuf[MAX_OUTBUF+1] = "";
static int outBufLen = 0;
static HWND outBufHwnd = NULL;
static LPVOID modules;
static EXCEPTION_POINTERS excPtrs;
static struct thread {HANDLE hThread; DWORD dwThreadId;} threads[MAX_THREADS];
static BOOL ignoreExceptions = FALSE;
static BOOL clearAlways = FALSE; 
static BOOL trapByDefault = FALSE; 

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpszCmdLine, int nCmdShow)
{
	WNDCLASS wndclass;
	MSG msg;

	if(!hPrevInstance) {
		wndclass.style = 0;
		wndclass.lpfnWndProc = WndProc;
		wndclass.cbClsExtra = 0;
		wndclass.cbWndExtra = 0;
		wndclass.hInstance = hInstance;
		wndclass.hIcon = LoadIcon(hInstance, "DEBUG");
		wndclass.hCursor = NULL;
		wndclass.hbrBackground = (HBRUSH)(COLOR_WINDOW);
		wndclass.lpszMenuName = "Debug_Menu";
		wndclass.lpszClassName = "Debug_Class";
     	if (!RegisterClass(&wndclass)) {
			return 1;
 		}
		wndclass.lpfnWndProc = ChildWndProc;
		wndclass.cbWndExtra = 4;
		wndclass.lpszMenuName = NULL;
		wndclass.lpszClassName = "Debug_Child_Class";
     	if (!RegisterClass(&wndclass)) {
			return 1;
 		}
	}

	hwndMain = CreateWindow("Debug_Class", Title, WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | 
		WS_MAXIMIZEBOX | WS_THICKFRAME | WS_CLIPCHILDREN | WS_OVERLAPPED,
 		CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, NULL, NULL, hInstance, NULL);

	if (hwndMain == NULL) {
		return 1;
	}

	hInst = hInstance;

 	ShowWindow(hwndMain, nCmdShow);
 	while(GetMessage(&msg, NULL, 0, 0)) {
		TranslateMessage(&msg);
		DispatchMessage(&msg);
	}

	UnregisterClass("Debug_Class", hInstance);
 	UnregisterClass("Debug_Child_Class", hInstance);
 	return msg.wParam;
} 

void Flush(void) {
	HWND hwndE;
	int len;

	if ((outBufLen > 0) && (outBufHwnd != NULL)) {
		hwndE = (HWND)GetWindowWord(outBufHwnd, GWW_HWNDEDIT);
		len = (int)SendMessage(hwndE, EM_GETLIMITTEXT, 0, 0);
		SendMessage(hwndE, EM_SETSEL, (WPARAM)len, (LPARAM)len);
		outBuf[outBufLen] = (char)0;
		SendMessage(hwndE, EM_REPLACESEL, (WPARAM)FALSE, (LPARAM)(&outBuf));
	}
	outBufLen = 0; outBufHwnd = NULL;
}

void Clear(HWND hWnd)  {
	HWND hwndE;
	int len;
	char msg[4] = "";

	Flush();
	if (hWnd != NULL) {
		hwndE = (HWND)GetWindowWord(hWnd, GWW_HWNDEDIT);
		len = (int)SendMessage(hwndE, EM_GETLIMITTEXT, 0, 0);
		SendMessage(hwndE, EM_SETSEL, (WPARAM)0, (LPARAM)len);
		SendMessage(hwndE, EM_REPLACESEL, (WPARAM)FALSE, (LPARAM)(&msg));
	}
}

void String(HWND hWnd, LPCSTR msg) {
	int i;

	if (hWnd != NULL) {
		if (hWnd != outBufHwnd) {
			Flush(); outBufHwnd = hWnd;
		}
		i = 0;
		while (msg[i] != (char)0) {
			outBuf[outBufLen] = msg[i];
			outBufLen++; i++;
			if (outBufLen >= MAX_OUTBUF) {
				Flush(); outBufHwnd = hWnd;
			}
		}
	} else {
		MessageBox(hwndMain, msg, Title, MB_OK | MB_APPLMODAL);
	}
}

LRESULT CALLBACK ChildWndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
	switch (uMsg) {
		case WM_CREATE: {
			HWND hwnd;

			if (LoadLibrary("RichED32.DLL") == NULL) {
				String(NULL, "Requires RichED32.DLL!\n");
			} else {
				hwnd = CreateWindow("RichEdit", NULL, WS_CHILD | WS_VISIBLE | WS_HSCROLL |
					WS_VSCROLL | ES_AUTOHSCROLL | ES_AUTOVSCROLL | ES_MULTILINE,
					0, 0, 0, 0, hWnd,	(HMENU)ID_EDIT,	hInst, (LPVOID)NULL);
				SetWindowWord(hWnd, GWW_HWNDEDIT, (WORD)hwnd);
			}
			break;
		}

		case WM_SIZE: {
			RECT rc;
			HWND hwnd;

			GetClientRect(hWnd, &rc);
			hwnd = (HWND)GetWindowWord(hWnd, GWW_HWNDEDIT);
			MoveWindow(hwnd, rc.left, rc.top, rc.right-rc.left, rc.bottom-rc.top, TRUE);
			return DefMDIChildProc(hWnd, uMsg, wParam, lParam);

			break;
		}

		case WM_CLOSE:
			return 0;
			break;

		default:
			return DefMDIChildProc(hWnd, uMsg, wParam, lParam);
	}
	return 0;
}

BOOL CALLBACK AboutDlgProc(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam) {
	if ((uMsg == WM_COMMAND) && (LOWORD(wParam) == IDD_Ok)) {
		EndDialog(hwndDlg, 0);
		return TRUE;
	}
	return FALSE;
}

OCHAR Get(LPVOID adr, LONGINT* i) {
	DWORD read;
	OCHAR ch;

	ReadProcessMemory(proc.hProcess, (LPVOID)((LONGINT)adr+(*i)), &ch, 1, &read);
	(*i)++;
	if (read < 1) {
		return (OCHAR)0;
	} else {
		return ch;
	}
}


short int GetInt(LPVOID adr, LONGINT* i) {
	DWORD read; short int x;

	ReadProcessMemory(proc.hProcess, (LPVOID)((LONGINT)adr+(*i)), &x, 2, &read);
	(*i) += 2;
	if (read < 2) {
		return 0;
	} else {
		return x;
	}
}

LONGINT GetLInt(LPVOID adr, LONGINT* i) {
	DWORD read; LONGINT x;

	ReadProcessMemory(proc.hProcess, (LPVOID)((LONGINT)adr+(*i)), &x, 4, &read);
	(*i) += 4;
	if (read < 4) {
		return 0;
	} else {
		return x;
	}
}

LONGINT GetNum(LPVOID adr, LONGINT* i) {
	LONGINT n, s; OCHAR x;
		
	return GetLInt(adr,i);

	s = 0; n = 0;
	x = Get(adr, i);
	while (x >= 128) {
		n = n + ((x-128) << s);	s = s + 7;
		x = Get(adr, i);
	}
	return (n + (( (x % 64) - (x / 64) * 64) << s));
}

LONGINT FindProc(LPVOID refs, LONGINT reflen, LONGINT ofs) {
	LONGINT proc, i, t, start, end;
	OCHAR ch;

	proc = -1; i = 1;
	ch = Get(refs, &i);
	while ((i < reflen) && ((ch == (OCHAR)0xf8) || (ch == (OCHAR)0xf9))) {
		start = GetNum(refs, &i);
		end = GetNum(refs, &i);
		
			if (ch == (OCHAR)0xf9) {
				t = GetNum(refs, &i);
				i += 9;
			}
			proc = i;
			do { ch = Get(refs, &i); } while (ch != 0);
			if (i < reflen) {
				ch = Get(refs, &i);
				while ((i < reflen) && (ch >= 0x1) && (ch <= 0x3)) {
					ch = Get(refs, &i);
					if ((ch >= 0x81) || (ch == 0x16) || (ch == 0x1D)) {
						t = GetNum(refs, &i);
					}
					t = GetNum(refs, &i);
					do { ch = Get(refs, &i); } while (ch != 0);
					if (i < reflen) { ch = Get(refs, &i); } 
				}
			};
			if ((start <= ofs) && (ofs <= end)) {ch = 0;}
		
	}
	if ((proc == -1) && (i != 0)) { proc = i; }
	return proc;
}

LPVOID GetMod(LONGINT pc) {
	LPVOID m;
	LONGINT base, len, i;
	//OCHAR msg[128];

	i = 0; m = (LPVOID)GetLInt(modules, &i);
	if (m==NULL) String(hwndSys, "no modules found at all"); 
	while (m != NULL) {
		i = 0; base = GetLInt((LPVOID)((DWORD)m+ModCode), &i); // code table
		i = 0; len = GetLInt((LPVOID)((DWORD)base+12), &i); // len (code table)
		// better: read len from len table within module desc

		//wsprintf(msg,"module from 0%lXH to 0%lXH with len 0%lXH \n",base+16,base+16+len,len); 
		//String(hwndSys,msg); 
		
		base = base+16;
		if ((base <= pc) && (pc <= (base+len))) {
			return m;
		}
		i = 0; base = GetLInt((LPVOID)((DWORD)m+ModData), &i);
		i = 0; len = GetLInt((LPVOID)((DWORD)base+12), &i);
		base = base+16;
		if ((pc >= base) && (pc <= (base+len))) {
			return m;
		}
		i = 0; m = (LPVOID)GetLInt((LPVOID)((DWORD)m+ModNext), &i);
	}
	return NULL;
}

void WriteProc(HWND hWnd, LPVOID mod, LONGINT pc, LONGINT bp, LPVOID* refs, LONGINT* reflen, LONGINT* refpos, LONGINT* base) {
	OCHAR msg[128];
	LONGINT i, j;
	DWORD read;
	OCHAR ch;

	(*refpos) = -1; (*reflen) = 0; (*base) = 0;
	if (mod == NULL) {
		wsprintf(msg, "Unknown EIP = 0%lXH", pc);
		String(hWnd, msg);
		if (bp != -1) {
			wsprintf(msg, " EBP = 0%lXH", bp);
			String(hWnd, msg);
		}
	} else {
		ReadProcessMemory(proc.hProcess, (LPVOID)((DWORD)mod+ModName), msg, 32, &read);
		String(hWnd, msg);
		j = 0; i = GetLInt((LPVOID)((DWORD)mod+ModCode), &j);

		//wsprintf(msg,"module code 0%lXH \n",i);
		//String(hwndSys,msg);

		i = i+16; 
		j = 0; i = GetLInt((LPVOID)((DWORD)mod+ModRefs), &j);

		//wsprintf(msg,"module refs 0%lXH \n",i);
		//String(hwndSys,msg);

		j = 0; (*reflen) = GetLInt((LPVOID)((DWORD)i+12), &j);
		(*refs) = (LPVOID)(i+16);
		if (((*refs) != NULL) && (reflen > 0)) {
			(*refpos) = FindProc((*refs), (*reflen), pc);
			if ((*refpos) != -1) {
				ch = Get((*refs), refpos);
				if (ch == '$') {
					j = 0; i = GetLInt((LPVOID)((DWORD)mod+ModSB), &j);
					(*base) = i;
				} else {
					(*base) = bp;
				}
				msg[0] = '.'; i = 1;
				while (ch != 0) {
					msg[i] = ch; i++;
					ch = Get((*refs), refpos);
				}
				msg[i] = 0;
				String(hWnd, msg);
			}
		}
		wsprintf(msg, "  PC = %i", pc);
		String(hWnd, msg);
	}
}

void GetTypeName(LPVOID ptr, char* name) {
	LPVOID tag, type, mod;
	int i;
	DWORD read;
	char mname[32], tname[32];

	if ((DWORD)ptr > 1024*1024) {
		i = -4; tag = (LPVOID)GetLInt(ptr, &i);
		if ((DWORD)tag > 1024*1024) {
			i = -4; type = (LPVOID)GetLInt(tag, &i);
			if ((DWORD)type > 1024*1024) {
				i = TypeTagMod; mod = (LPVOID)GetLInt(type, &i); // 48 -> TypeTagMod
				ReadProcessMemory(proc.hProcess, (LPVOID)((DWORD)mod+ModName), mname, 32, &read);
				ReadProcessMemory(proc.hProcess, (LPVOID)((DWORD)type+TypeTagName), tname, 32, &read); // 16 -> TypeTagName
				if (strcmp(tname,"") == 0) {strcpy(tname,"ANONYMOUS");}
				if (strcmp(mname,"") == 0) {strcpy(mname,"ANONYMOUS");}
				sprintf(name, "%s.%s", mname, tname);
				return;
			}
		}
	}
	strcpy(name, "");
}

void WriteType(HWND hWnd, LPVOID dynamictdadr, LPVOID statictdadr) {
	char dname[64], sname[64];
	char msg[128];

	GetTypeName(dynamictdadr, dname);
	if (strcmp(dname, "") != 0) {
		wsprintf(msg, " %s", dname);
		String(hWnd, msg);
	}
	/* not supported any more since records do not have a type descriptor in the module heap
	GetTypeName(statictdadr, sname);
	if ((strcmp(sname, "") != 0)&& (strcmp(sname, dname) != 0)) {
		wsprintf(msg, " (%s)", dname);
		String(hWnd, msg);
	}
	*/
}

void Variables(HWND hWnd, LPVOID mod, LPVOID refs, LONGINT reflen, LONGINT i, LONGINT base, LONGINT sb) {
	OCHAR msg[MaxString+4];
	LPVOID tmp, tdadr0, tdadr1;
	LONGINT n, adr, size, j, k, t, t2, t3, vars;
	DWORD read;
	OCHAR mode, type, ch;
	BOOLEAN writeType; 
	short int si;
	BOOLEAN etc;
	float x;
	double y;

	mode = Get(refs, &i); vars = 0;
	while ((i < reflen) && (mode >= 0x1) && (mode <= 0x3) && (vars < MAX_VARS)) {
		tdadr0 = NULL; tdadr1 = NULL;
		type = Get(refs, &i); etc = FALSE;

		//wsprintf(msg,"type:  0%lXH \n",type);
		//String(hwndSys,msg);


		if (type > 0x80) {
			if (type == 0x83) { type = 15; } else { type -= 0x80; }
			n = GetNum(refs, &i);
		} else if ((type == 0x16) || (type == 0x1D)) {
			tdadr0 = (LPVOID)GetNum(refs, &i); n = 1;
			//wsprintf(msg,"tdadr0:  0%lXH \n",tdadr0);
			//String(hwndSys,msg);
			if (((DWORD)tdadr0 >= 0) && ((DWORD)tdadr0 <= 1024*1024)) {
				j = 0; k = GetLInt((LPVOID)((DWORD)mod+ModSB), &j);
				j = 0; tdadr0 = (LPVOID)GetLInt((LPVOID)(k+(DWORD)tdadr0), &j);
			//wsprintf(msg,"tdadr0(2):  0%lXH \n",tdadr0);
			//String(hwndSys,msg);
			}
		} else {
			if (type == 15) { n = MaxString; } else { n = 1; }
		}
		adr = GetNum(refs, &i); adr = adr+base;
		wsprintf(msg, "\t"); j = 1;
		ch = Get(refs, &i);
		while (ch != 0) {
			msg[j] = ch; j++;
			ch = Get(refs, &i);
		}
		msg[j] = 0; String(hWnd, msg);
		String(hWnd, " = ");
		if (n == 0) {
			k = 0; n = GetLInt((LPVOID)(adr+4), &k);
		}
		if (type == 15) {
			if (n > MaxString) { etc = TRUE; n = MaxString; }
		} else {
			if (n > MaxArray) { etc = TRUE; n = MaxArray; }
		}
		if (mode != 0x1) {
			k = 0; adr = GetLInt((LPVOID)(adr), &k);
		}
		if ((adr >= -4) && (adr < 4096)) {
			wsprintf(msg, "NIL reference (0%lXH)", adr);
			String(hWnd, msg);
		} else {
			if (type == 15) {
				msg[0] = '"'; j = 1; k = 0;
				while (n > 0) {
					ch = Get((LPVOID)adr, &k);
					if ((ch < ' ') || (ch > '~')) { break; }
					msg[j] = ch; j++; n--;
				}
				msg[j] = '"'; msg[j+1] = (OCHAR)0;
				etc	= (ch != 0); String(hWnd, msg);
			} else {
				switch (type) {
					case 1: case 2: case 3: case 4: size = 1; break;
					case 5: size = 2; break;
					case 6: case 7: case 9: case 13: case 14: case 29: size = 4; break;
					case 8: case 16: size = 8; break;
					case 22: size = 0; break;
					default:
						wsprintf(msg, "bad type %i", (int)type);
						String(hWnd, msg);
						n = 0; size = 0;
				}
				while (n > 0) {
					k = 0;
					writeType = 0;
					switch (type) {
						case 1: case 3: // byte, char
							ch = Get((LPVOID)adr, &k);
							if ((ch > ' ') && (ch <= '~')) {
								msg[0] = ch; msg[1] = 0;
							} else {
								wsprintf(msg, "%uX", ch);
							}
							break;
						case 2: // BOOLEAN
							ch = Get((LPVOID)adr, &k);
							if (ch == 0) {
								wsprintf(msg, "FALSE");
							} else if (ch == 1) {
								wsprintf(msg, "TRUE");
							} else {
								wsprintf(msg, "%i", ch);
							}
							break;
						case 4: // SHORTINT
							ch = Get((LPVOID)adr, &k);
							wsprintf(msg, "%i", ch);
							break;
						case 5: // INTEGER
							si = GetInt((LPVOID)adr, &k);
							wsprintf(msg, "%i", si);
							break;
						case 6: // LONGINT
							j = GetLInt((LPVOID)adr, &k);
							wsprintf(msg, "%i", j);
							break;
						case 7: // REAL
							ReadProcessMemory(proc.hProcess, (LPVOID)adr, &x, 4, &read);
							sprintf(msg, "%E", x);
							break;
						case 8: // LONGREAL
							ReadProcessMemory(proc.hProcess, (LPVOID)adr, &y, 8, &read);
							sprintf(msg, "%E", y);
							break;
						case 9: // SET
							j = GetLInt((LPVOID)adr, &k);
							wsprintf(msg, "0%lXH", j);
							break;
						case 13: case 29: // pointer
							tdadr1 = (LPVOID)GetLInt((LPVOID)adr, &k);
							wsprintf(msg, "0%lXH", tdadr1);
							writeType = 1; 
							break;
						case 22: // RECORD
							tdadr1 = tdadr0; 
							wsprintf(msg, "RECORD 0%lXH", tdadr1);
							break;
						case 14: // PROC
							j = GetLInt((LPVOID)adr, &k);
							if (j == 0) {
								wsprintf(msg, "NIL");
							} else {
								tmp = NULL; t = 0; t2 = 0; t3 = 0;
								WriteProc(hWnd, GetMod(j), j, -1, &tmp, &t, &t2, &t3);
								wsprintf(msg, "");
							}
							break;
					}
					String(hWnd, msg);
					
					if (writeType==1) {
						WriteType(hWnd, tdadr1, tdadr0);
					}
					 
					n--; adr += size;
					if (n > 0) { String(hWnd, ","); }
				}
			}
		}
		if (etc) {
			wsprintf(msg, "...\n");
		} else {
			wsprintf(msg, "\n");
		}
		String(hWnd, msg);
		if (i < reflen) { mode = Get(refs, &i); }
		vars++;
	}
}

void ShowState(OCHAR* module) {
	LPVOID mod, refs;
	LONGINT sb, reflen, refpos, i;
	DWORD read;
	OCHAR modName[32] = "";
	OCHAR msg[64];
	OCHAR ch;

	wsprintf(msg, "Module State %s\n", module); String(hwndSys, msg);
	i = 0; mod = (LPVOID)GetLInt(modules, &i);
	while (mod != NULL) {
		ReadProcessMemory(proc.hProcess, (LPVOID)((DWORD)mod+ModName), modName, 32, &read);
		if (strcmp(modName, module) != 0) {
			i = 0; mod = (LPVOID)GetLInt((LPVOID)((DWORD)mod+ModNext), &i);
		} else {
			break;
		}
	}
	if (strcmp(modName, module) == 0) {
		i = 0; sb = GetLInt((LPVOID)((DWORD)mod+ModSB), &i);
		wsprintf(msg, "  SB = 0%lXH\n", sb); String(hwndSys, msg);
		i = 0; refs = (LPVOID)GetLInt((LPVOID)((DWORD)mod+ModRefs), &i);
		i = 0; reflen = GetLInt((LPVOID)((DWORD)refs+12), &i);
		refs = (LPVOID)((DWORD)refs+16);
		if ((refs != NULL) && (reflen > 0)) {
			refpos = FindProc(refs, reflen, 0);
			if (refpos != -1) {
				do { ch = Get(refs, &refpos); } while (ch != 0);
				Variables(hwndSys, mod, refs, reflen, refpos, sb, sb);
			}
		}
	} else {
		wsprintf(msg, "\tNot Loaded\n"); String(hwndSys, msg);
	}
	String(hwndSys, "\n"); Flush();
}

void TrapMsg(EXCEPTION_POINTERS *exp, LPSTR msg, BOOL ln) {
	OCHAR form[32];
	DWORD excode;

	if (ln) {
		strcpy(form, "%s\n");
	} else {
		strcpy(form, "%s");
	}
	excode = exp->ExceptionRecord->ExceptionCode;
	if (excode == EXCEPTION_GUARD_PAGE) {
		wsprintf(msg, form, "guard page violation");
	} else if (excode == EXCEPTION_BREAKPOINT) {
		LONGINT i, code;
		i = 0; code = GetLInt((LPVOID)(exp->ContextRecord->Esp), &i);
		if (ln) {
			wsprintf(form, "%i  %s\n", code, "%s");
		} else {
			wsprintf(form, "%i  %s", code, "%s");
		}
		if (code == 1) {
			wsprintf(msg, form, "WITH guard failed");
		} else if (code == 2) {
			wsprintf(msg, form, "CASE invalid");
		} else if (code == 3) {
			wsprintf(msg, form, "RETURN missing");
		} else if (code == 5) {
			wsprintf(msg, form, "Implicit type guard failed");
		} else if (code == 6) {
			wsprintf(msg, form, "Type guard failed");
		} else if (code == 7) {
			wsprintf(msg, form, "Index out of range");
		} else if (code == 8) {
			wsprintf(msg, form, "ASSERT failed");
		} else if (code == 9) {
			wsprintf(msg, form, "Array dimension error");
		} else if (code == 13) {
			wsprintf(msg, form, "Keyboard interrupt");
		} else if (code == 14) {
			wsprintf(msg, form, "Out of memory");
		} else if (code == 23) {
			wsprintf(msg, form, "Exceptions.Raise");
		} else {
			wsprintf(msg, form, "HALT statement");
		}
	} else if (excode == EXCEPTION_SINGLE_STEP) {
		wsprintf(msg, form, "single step");
	} else if (excode == EXCEPTION_ACCESS_VIOLATION) {
		wsprintf(msg, form, "access violation");
	} else if (excode == EXCEPTION_ILLEGAL_INSTRUCTION) {
		wsprintf(msg, form, "illegal instruction");
	} else if (excode == EXCEPTION_ARRAY_BOUNDS_EXCEEDED) {
		wsprintf(msg, form, "index out of range");
	} else if (excode == EXCEPTION_FLT_DENORMAL_OPERAND) {
		wsprintf(msg, form, "FPU: denormal operand");
	} else if (excode == EXCEPTION_FLT_DIVIDE_BY_ZERO) {
		wsprintf(msg, form, "FPU: divide by zero");
	} else if (excode == EXCEPTION_FLT_INEXACT_RESULT) {
		wsprintf(msg, form, "FPU: inexact result");
	} else if (excode == EXCEPTION_FLT_INVALID_OPERATION) {
		wsprintf(msg, form, "FPU: invalid operation");
	} else if (excode == EXCEPTION_FLT_OVERFLOW) {
		wsprintf(msg, form, "FPU: overflow");
	} else if (excode == EXCEPTION_FLT_STACK_CHECK) {
		wsprintf(msg, form, "FPU: stack check");
	} else if (excode == EXCEPTION_FLT_UNDERFLOW) {
		wsprintf(msg, form, "FPU: undeflow");
	} else if (excode == EXCEPTION_INT_DIVIDE_BY_ZERO) {
		wsprintf(msg, form, "integer division by zero");
	} else if (excode == EXCEPTION_INT_OVERFLOW) {
		wsprintf(msg, form, "integer overflow");
	} else if (excode == EXCEPTION_PRIV_INSTRUCTION) {
		wsprintf(msg, form, "privileged instruction");
	} else if (excode == EXCEPTION_STACK_OVERFLOW) {
		wsprintf(msg, form, "stack overflow");
	} else {
		if (ln) {
			wsprintf(msg, "exception %i\n", excode);
		} else {
			wsprintf(msg, "exception %i\n", excode);
		}
	}
}

void ShowStack(EXCEPTION_POINTERS *exp, BOOL trap) {
	LONGINT pc, bp, sp, reflen, refpos, base, sb, lastbp, frames, i;
	LPVOID mod, refs;
	OCHAR msg[128];

	pc = (LONGINT)(exp->ExceptionRecord->ExceptionAddress);
	bp = exp->ContextRecord->Ebp; sp = exp->ContextRecord->Esp;
	if (pc == (LONGINT)NULL) {
		i = 0; pc = GetLInt((LPVOID)(sp), &i);
	}
	if (trap) {
		TrapMsg(exp, msg, TRUE);
	} else {
		//wsprintf(msg, StackFrames\n");
		wsprintf(msg,""); 
	}
	String(hwndSys, msg);
	wsprintf(msg, "\n"); String(hwndSys, msg);
	mod = GetMod(pc); frames = 0;
	while (frames < MAX_FRAMES){
		refs = NULL; refpos = 0; base = 0;
		WriteProc(hwndSys, mod, pc, bp, &refs, &reflen, &refpos, &base);
		wsprintf(msg, "\n");
		String(hwndSys, msg);
		if (refpos != -1) {
			i = 0; sb = GetLInt((LPVOID)((DWORD)mod+ModSB), &i);
			Variables(hwndSys, mod, refs, reflen, refpos, base, sb);
		}
		lastbp = bp;
		i = 0; pc = GetLInt((LPVOID)(bp+4), &i);
		i = 0; bp = GetLInt((LPVOID)(bp), &i);
		if ((bp < lastbp) || (bp == 0)) { break; }
		mod = GetMod(pc); frames++;
	}
	Flush();
}

void ShowAllStacks()
{
	OCHAR str[64]; int i; 
				i = 0;excPtrs.ExceptionRecord = (PEXCEPTION_RECORD)malloc(sizeof(EXCEPTION_RECORD));
				while (i < MAX_THREADS) {
					if (threads[i].hThread != INVALID_HANDLE_VALUE) {	
						excPtrs.ContextRecord->ContextFlags = CONTEXT_FULL;
						GetThreadContext(threads[i].hThread, excPtrs.ContextRecord);
						excPtrs.ExceptionRecord->ExceptionCode = 0;
						excPtrs.ExceptionRecord->ExceptionAddress = (LPVOID)(excPtrs.ContextRecord->Eip);
						wsprintf(str, "\n ThreadId: %lu", threads[i].dwThreadId); 
						String(hwndSys, str);
						ShowStack(&excPtrs, FALSE);
					}
					i++;
				}
				free(excPtrs.ExceptionRecord);
				
}
DWORD WINAPI ThreadProc(LPVOID arg) {
	HANDLE hProcess = NULL, hExcThread;
	DEBUG_EVENT event;
	DWORD processId, read, len, i, val, level;
	LPCSTR debStr;
	OCHAR msg[1024];
	OCHAR mystring[64];
	BOOL ignore, fetchAdr;

	ignore = TRUE;
	if (CreateProcess(exePath, NULL, NULL, NULL, FALSE, DEBUG_PROCESS, NULL, workPath,
		&start, &proc)) {
		WritePrivateProfileString("Debug", "Exe", exePath, iniFile);
		ignore = FALSE;
	} else {
		sscanf(exePath, "%lu", &processId);
		if (DebugActiveProcess(processId) != 0) {
			ignore = FALSE;
		}
	}
	if (!ignore) {
		EnableMenuItem(GetMenu(hwndMain), IDM_D_Stop, MF_BYCOMMAND);
		String(hwndSys, "Debugger started\n"); Flush();
		modules = NULL; ignore = TRUE; fetchAdr = FALSE; level = 0;
		i = 0;
		while (i < MAX_THREADS) {
			threads[i].hThread = INVALID_HANDLE_VALUE;
			threads[i].dwThreadId = 0;
			i++;
		}
		while (WaitForDebugEvent(&event, INFINITE)) {
			debugAction = DBG_CONTINUE;
			switch (event.dwDebugEventCode) {
				case EXCEPTION_DEBUG_EVENT:
					if (!ignore) {
						if (!ignoreExceptions) {
							i = 0;
							while ( (i < MAX_THREADS) && (threads[i].dwThreadId != event.dwThreadId)) {
								i++;
							}
							if (i < MAX_THREADS) {
								hExcThread = threads[i].hThread;
								excPtrs.ExceptionRecord = &(event.u.Exception.ExceptionRecord);
								excPtrs.ContextRecord->ContextFlags = CONTEXT_FULL;
								GetThreadContext(hExcThread, excPtrs.ContextRecord);
								
								TrapMsg(&excPtrs, msg, FALSE);
								String(hwndExc, msg); Flush();
								if (trapByDefault == TRUE) 
								{	
									if (clearAlways==TRUE) Clear(hwndSys);
									ShowStack(&excPtrs, TRUE);
									debugAction = DBG_EXCEPTION_NOT_HANDLED;
								} else {
									EnableMenuItem(GetMenu(hwndMain), IDM_A_CONTINUE, MF_BYCOMMAND);
								EnableMenuItem(GetMenu(hwndMain), IDM_A_EXCEPTION, MF_BYCOMMAND);
								EnableMenuItem(GetMenu(hwndMain), IDM_A_TRAP, MF_BYCOMMAND);
									SuspendThread(hThread);
										
								}
								if (debugAction == DBG_CONTINUE) {
									String(hwndExc, " Continue\n");
								} else {
									String(hwndExc, " Exception\n");
								}
							} else {
								debugAction = DBG_EXCEPTION_NOT_HANDLED;
								String(hwndExc, " unknown thread\n");
							}
						} else {
							debugAction = DBG_EXCEPTION_NOT_HANDLED;
						}
					} else {
						ignore = FALSE;
					}
					break;

				case CREATE_THREAD_DEBUG_EVENT:
					wsprintf(msg, "CreateThread %i\n", event.dwThreadId);
					String(hwndExc, msg);
					i = 0;
					while ((threads[i].dwThreadId != event.dwThreadId) && (threads[i].hThread != INVALID_HANDLE_VALUE)) {
						i++;
					}
					threads[i].hThread = event.u.CreateThread.hThread;
					threads[i].dwThreadId = event.dwThreadId;
					break;

				case EXIT_THREAD_DEBUG_EVENT:
					wsprintf(msg, "ExitThread %i\n", event.dwThreadId);
					String(hwndExc, msg);
					i = 0;
					while (threads[i].dwThreadId != event.dwThreadId) {
						i++;
					}
					threads[i].hThread = INVALID_HANDLE_VALUE;
					threads[i].dwThreadId = 0;
					break;

				case CREATE_PROCESS_DEBUG_EVENT:
					if (hProcess == NULL) {
						hProcess = event.u.CreateProcessInfo.hProcess;
						processId = event.dwProcessId;
						wsprintf(msg, "CreateProcess (Thread %i)\n", event.dwThreadId);
						String(hwndExc, msg);
						i = 0;
						while ((threads[i].dwThreadId != event.dwThreadId) && (threads[i].hThread != INVALID_HANDLE_VALUE)) {
							i++;
						}
						threads[i].hThread = event.u.CreateProcessInfo.hThread;
						threads[i].dwThreadId = event.dwThreadId;
					} else {

					}
					break;

				case EXIT_PROCESS_DEBUG_EVENT:
					if (event.dwProcessId == processId) {
						wsprintf(msg, "ExitProcess (ret %i)\n", event.u.ExitProcess.dwExitCode);
						String(hwndExc, msg); Flush();
						PostMessage(hwndMain, WM_STOP, 0, 0);
						ExitThread(0);
					} else {

					}
					break;

				case OUTPUT_DEBUG_STRING_EVENT:
					debStr = event.u.DebugString.lpDebugStringData;
					len = event.u.DebugString.nDebugStringLength; read = len;
					while ((len > 0) && (read > 0)) {
						if (len > 1023 ) {
							ReadProcessMemory(proc.hProcess, debStr, msg, 1023, &read);
						} else {
							ReadProcessMemory(proc.hProcess, debStr, msg, len, &read);
							if (level == 0 ) {
								if (fetchAdr) {
									modules = NULL; i = 0;
									while ((msg[i] > ' ') && (i < read)) {
										if ((msg[i] >= '0') && (msg[i] <= '9')) {
											val = (DWORD)(msg[i])-(DWORD)'0';
										} else {
											val = 10+(DWORD)(msg[i])-(DWORD)'A';
										}
										modules = (LPVOID)(16*(DWORD)modules+val);
										i++;
									}
									wsprintf(mystring,"Oberon ready. (Modules= 0%lXH) \n",modules);
									level++; String(hwndSys, mystring);
									EnableMenuItem(GetMenu(hwndMain), IDM_A_STATE, MF_BYCOMMAND);
									EnableMenuItem(GetMenu(hwndMain), IDM_A_STACK, MF_BYCOMMAND);
									EnableMenuItem(GetMenu(hwndMain), IDM_A_ALLSTACKS, MF_BYCOMMAND);

									fetchAdr = FALSE;
								} else if (strncmp(msg, "Modules.root", 21) == 0) {
									fetchAdr = TRUE;
								}
							} else if ((level > 0) && (strncmp(msg, "Modules.Shutdown", 19) == 0)) {
								EnableMenuItem(GetMenu(hwndMain), IDM_A_STATE, MF_BYCOMMAND | MF_GRAYED);
								EnableMenuItem(GetMenu(hwndMain), IDM_A_STACK, MF_BYCOMMAND | MF_GRAYED);
								EnableMenuItem(GetMenu(hwndMain), IDM_A_ALLSTACKS, MF_BYCOMMAND | MF_GRAYED);

								level = 0; fetchAdr = FALSE; modules = NULL;
								String(hwndSys, "Oberon stopped\n");
							}
						}
						debStr = debStr+read; len = len-read;
						msg[read] = (OCHAR)0;
// translate from Oberon to Windows
						String(hwndCon, msg);
					}
					break;

				default:

					break;
			}
			Flush();
			ContinueDebugEvent(event.dwProcessId, event.dwThreadId, debugAction);
		}
	} else {
		String(hwndExc, "CreateProcess failed!\n"); Flush();
	}
	PostMessage(hwndMain, WM_STOP, 0, 0);
	ExitThread(0);
	return 0;
}

BOOL CALLBACK StateDlgProc(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam) {
	switch (uMsg) {
		case WM_INITDIALOG: {
				HWND hwndCB;
				LPVOID mod;
				DWORD read;
				LONGINT i;
				OCHAR modName[32];

				strcpy(module, ""); strcpy(workPath, "");
				GetPrivateProfileString("Debug", "Module", workPath, module, MaxString, iniFile);
				SetDlgItemText(hwndDlg, IDD_State, module);
				hwndCB = GetDlgItem(hwndDlg, IDD_State);
				i = 0; mod = (LPVOID)GetLInt(modules, &i);
				while (mod != NULL) {
					ReadProcessMemory(proc.hProcess, (LPVOID)((DWORD)mod+ModName), modName, 32, &read);
					SendMessage(hwndCB, CB_ADDSTRING, (WPARAM)0, (LPARAM)(&modName));
					i = 0; mod = (LPVOID)GetLInt((LPVOID)((DWORD)mod+ModNext), &i);
				}
				return TRUE;
			}
			break;
		case WM_COMMAND:
			if (LOWORD(wParam) == IDD_Ok) {
				GetDlgItemText(hwndDlg, IDD_State, module, MaxString);
				if (strcmp(module, "") != 0) {
					WritePrivateProfileString("Debug", "Module", module, iniFile);
				}
				EndDialog(hwndDlg, 0);
				return TRUE;
			} else if (LOWORD(wParam) == IDD_Cancel) {
				strcpy(module, "");
				EndDialog(hwndDlg, 0);
				return TRUE;
			}
			break;

		default:
			return FALSE;
	}
	return FALSE;
}

BOOL CALLBACK StackDlgProc(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam) {
	int i; 

	switch (uMsg) {
		case WM_INITDIALOG: {
				HWND hwndCB;
				DWORD i;
				OCHAR str[64];

				strcpy(module, ""); strcpy(workPath, "");
				GetPrivateProfileString("Debug", "Thread", workPath, module, MaxString, iniFile);
				SetDlgItemText(hwndDlg, IDD_Stack, module);
				hwndCB = GetDlgItem(hwndDlg, IDD_Stack);
				i = 0;
				while (i < MAX_THREADS) {
					if (threads[i].hThread != INVALID_HANDLE_VALUE) {
						wsprintf(str, "%lu", threads[i].dwThreadId);
						SendMessage(hwndCB, CB_ADDSTRING, (WPARAM)0, (LPARAM)(&str));
					}
					i++;
				}
				return TRUE;
			}
			break;
		case WM_COMMAND:
			if (LOWORD(wParam) == IDD_Ok) {
				GetDlgItemText(hwndDlg, IDD_Stack, module, MaxString);
				if (strcmp(module, "") != 0) {
					WritePrivateProfileString("Debug", "Thread", module, iniFile);
				}
				EndDialog(hwndDlg, 0);
				return TRUE;
			} else if (LOWORD(wParam) == IDD_Cancel) {
				strcpy(module, "");
				EndDialog(hwndDlg, 0);
				return TRUE;
			} else if (LOWORD(wParam) == IDD_AllStacks) // show all stacks
				{
					if (clearAlways==TRUE) Clear(hwndSys);
					ShowAllStacks(); 

				/* OCHAR str[64];
				i = 0;excPtrs.ExceptionRecord = (PEXCEPTION_RECORD)malloc(sizeof(EXCEPTION_RECORD));
				if (clearAlways==TRUE) Clear(hwndSys);
				while (i < MAX_THREADS) {
					if (threads[i].hThread != INVALID_HANDLE_VALUE) {	
						excPtrs.ContextRecord->ContextFlags = CONTEXT_FULL;
						GetThreadContext(threads[i].hThread, excPtrs.ContextRecord);
						excPtrs.ExceptionRecord->ExceptionCode = 0;
						excPtrs.ExceptionRecord->ExceptionAddress = (LPVOID)(excPtrs.ContextRecord->Eip);
						wsprintf(str, "\n ThreadId: %lu", threads[i].dwThreadId); 
						String(hwndSys, str);
						ShowStack(&excPtrs, FALSE);
					}
					i++;
				}
				free(excPtrs.ExceptionRecord);
				*/
				EndDialog(hwndDlg, 0);
				strcpy(module, "");
				return TRUE;
			}
				
			break;

		default:
			return FALSE;
	}
	return FALSE;
}

BOOL CALLBACK StartDlgProc(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam) {
	INT i, j;

	switch (uMsg) {
	case WM_INITDIALOG: {
				HWND hwndCB;
				char key[32];
				char str[MAX_PATH];

				SetDlgItemText(hwndDlg, IDD_ExePath, exePath);
				hwndCB = GetDlgItem(hwndDlg, IDD_ExePath);
				i = 1; j = 0;
				do {
					wsprintf(key, "Exe%i", i); i++;
					strcpy(str, ""); strcpy(workPath, "");
					j = GetPrivateProfileString("Debug", key, workPath, str, MAX_PATH, iniFile);
					if (j > 0) {
						SendMessage(hwndCB, CB_ADDSTRING, (WPARAM)0, (LPARAM)(&str));
					}
				} while (j > 0);
				return TRUE;
			}
			break;

		case WM_COMMAND:
			if (LOWORD(wParam) == IDD_Ok) {
				GetDlgItemText(hwndDlg, IDD_ExePath, exePath, MAX_PATH);
				strcpy(workPath, exePath);
				i = 0; j = -1;
				while (workPath[i] != (OCHAR)0) {
					if (workPath[i] == '\\') {
						j = i;
					}
					i++;
				}
				workPath[j+1] = (OCHAR)0;
				SendMessage(hwndMain, WM_START, 0, 0);
				EndDialog(hwndDlg, 0);
				return TRUE;
			} else if (LOWORD(wParam) == IDD_Open) {
				OPENFILENAME ofn;
				char filter[32];

				ZeroMemory(&ofn, sizeof(ofn));
				ofn.lStructSize = sizeof(ofn);
				ofn.hwndOwner = hwndDlg;
				strcpy(filter, "Executable Files *.EXE");
				filter[16] = 0; filter[22] = 0; filter[23] = 0;
				ofn.lpstrFilter = filter;
				ofn.lpstrFile = exePath;
				ofn.nMaxFile = MAX_PATH;
				if (GetOpenFileName(&ofn)) {
					SetDlgItemText(hwndDlg, IDD_ExePath, exePath);
				}
				return TRUE;
			} else if (LOWORD(wParam) == IDD_Cancel) {
				EnableMenuItem(GetMenu(hwndMain), IDM_D_Start, MF_BYCOMMAND);
				EnableMenuItem(GetMenu(hwndMain), IDM_D_Attach, MF_BYCOMMAND);
				EndDialog(hwndDlg, 0);
				return TRUE;
			}
			break;

		default:
			return FALSE;
	}
	return FALSE;
}

BOOL CALLBACK AttachDlgProc(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam) {

	switch (uMsg) {
		case WM_INITDIALOG:
			SetDlgItemText(hwndDlg, IDD_ProcessID, "");
			return TRUE;
			break;

		case WM_COMMAND:
			if (LOWORD(wParam) == IDD_Ok) {
				GetDlgItemText(hwndDlg, IDD_ProcessID, exePath, MAX_PATH);
				SendMessage(hwndMain, WM_START, 0, 0);
				EndDialog(hwndDlg, 0);
				return TRUE;
			} else if (LOWORD(wParam) == IDD_Cancel) {
				EnableMenuItem(GetMenu(hwndMain), IDM_D_Start, MF_BYCOMMAND);
				EnableMenuItem(GetMenu(hwndMain), IDM_D_Attach, MF_BYCOMMAND);
				EndDialog(hwndDlg, 0);
				return TRUE;
			}
			break;

		default:
			return FALSE;
	}
	return FALSE;
}

LRESULT CALLBACK WndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {

	switch (uMsg) {
		case WM_START:
			Clear(hwndCon); Clear(hwndExc); Clear(hwndSys);
			EnableMenuItem(GetMenu(hWnd), IDM_D_Start, MF_BYCOMMAND | MF_GRAYED);
			EnableMenuItem(GetMenu(hWnd), IDM_D_Attach, MF_BYCOMMAND | MF_GRAYED);
			hThread = CreateThread(NULL, 0, ThreadProc, NULL, 0, &threadId);
			break;

    	case WM_STOP:
			EnableMenuItem(GetMenu(hWnd), IDM_A_STATE, MF_BYCOMMAND | MF_GRAYED);
			EnableMenuItem(GetMenu(hWnd), IDM_A_STACK, MF_BYCOMMAND | MF_GRAYED);
			EnableMenuItem(GetMenu(hWnd), IDM_A_ALLSTACKS, MF_BYCOMMAND | MF_GRAYED);
			EnableMenuItem(GetMenu(hWnd), IDM_D_Stop, MF_BYCOMMAND | MF_GRAYED);
			if (proc.hThread != INVALID_HANDLE_VALUE) {
				CloseHandle(proc.hThread);
				proc.hThread = INVALID_HANDLE_VALUE;
			}
			if (proc.hProcess != INVALID_HANDLE_VALUE) {
				TerminateProcess(proc.hProcess, 0);
				CloseHandle(proc.hProcess);
				proc.hProcess = INVALID_HANDLE_VALUE;
			}
			TerminateThread(hThread, 0);
			CloseHandle(hThread);
			String(hwndSys, "Debugger stopped\n"); Flush();
			hThread = INVALID_HANDLE_VALUE;
			EnableMenuItem(GetMenu(hwndMain), IDM_D_Start, MF_BYCOMMAND);
			EnableMenuItem(GetMenu(hwndMain), IDM_D_Attach, MF_BYCOMMAND);
			break;

		case WM_COMMAND:
			switch (LOWORD(wParam)) {
				case IDM_D_Start:
					EnableMenuItem(GetMenu(hWnd), IDM_D_Start, MF_BYCOMMAND | MF_GRAYED);
					EnableMenuItem(GetMenu(hWnd), IDM_D_Attach, MF_BYCOMMAND | MF_GRAYED);
					DialogBox(hInst, "Debug_Start_Dialog", hWnd, StartDlgProc);
					break;
				case IDM_D_Attach:
					EnableMenuItem(GetMenu(hWnd), IDM_D_Start, MF_BYCOMMAND | MF_GRAYED);
					EnableMenuItem(GetMenu(hWnd), IDM_D_Attach, MF_BYCOMMAND | MF_GRAYED);
					DialogBox(hInst, "Debug_Attach_Dialog", hWnd, AttachDlgProc);
					break;
				case IDM_D_Stop:		
					SendMessage(hWnd, WM_STOP, 0, 0);
					break;
				case IDM_D_Exit:
					SendMessage(hWnd, WM_CLOSE, 0, 0);
					break;

				case IDM_W_ONTOP:
					if (CheckMenuItem(GetMenu(hWnd), IDM_W_ONTOP, MF_BYCOMMAND | MF_CHECKED) == MF_CHECKED) {
						CheckMenuItem(GetMenu(hWnd), IDM_W_ONTOP, MF_BYCOMMAND | MF_UNCHECKED);
						SetWindowPos(hWnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
						WritePrivateProfileString("Debug", "OnTop", "Off", iniFile);
					} else {
						SetWindowPos(hWnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
						WritePrivateProfileString("Debug", "OnTop", "On", iniFile);
					}
					break;

				case IDM_W_TILE:
					SendMessage(hwndMDIClient, WM_MDITILE, 0, 0);
					break;

				case IDM_W_CASCADE:
					SendMessage(hwndMDIClient, WM_MDICASCADE, 0, 0);
					break;

				case IDM_W_ICONS:
					SendMessage(hwndMDIClient, WM_MDIICONARRANGE, 0, 0);
					break;

				case IDM_W_CALL:
					Clear(hwndCon); Clear(hwndExc); Clear(hwndSys);
					break;

				case IDM_W_CCONSOLE:
					Clear(hwndCon);
					break;

				case IDM_W_CEXCEPTION:
					Clear(hwndExc);
					break;

				case IDM_W_CSYSTEM:
					Clear(hwndSys);
					break;

				case IDM_H_About:
					DialogBox(hInst, "Debug_About_Dialog", hWnd, AboutDlgProc);
					break;

				case IDM_A_IGNORE:
					if (CheckMenuItem(GetMenu(hWnd), IDM_A_IGNORE, MF_BYCOMMAND | MF_CHECKED) == MF_CHECKED) {
						CheckMenuItem(GetMenu(hWnd), IDM_A_IGNORE, MF_BYCOMMAND | MF_UNCHECKED);
						ignoreExceptions = FALSE;
						WritePrivateProfileString("Debug", "Ignore", "Off", iniFile);
					} else {
						ignoreExceptions = TRUE;
						WritePrivateProfileString("Debug", "Ignore", "On", iniFile);
					}
					break;
				case IDM_A_CLEARDEFAULT:
						if (CheckMenuItem(GetMenu(hWnd), IDM_A_CLEARDEFAULT, MF_BYCOMMAND | MF_CHECKED) == MF_CHECKED) {
						CheckMenuItem(GetMenu(hWnd), IDM_A_CLEARDEFAULT, MF_BYCOMMAND | MF_UNCHECKED);
						clearAlways = FALSE;
						WritePrivateProfileString("Debug", "Clear", "Off", iniFile);
					} else {
						clearAlways = TRUE;
						WritePrivateProfileString("Debug", "Clear", "On", iniFile);
					}
					break;
					case IDM_A_TRAPDEFAULT:
						if (CheckMenuItem(GetMenu(hWnd), IDM_A_TRAPDEFAULT, MF_BYCOMMAND | MF_CHECKED) == MF_CHECKED) {
						CheckMenuItem(GetMenu(hWnd), IDM_A_TRAPDEFAULT, MF_BYCOMMAND | MF_UNCHECKED);
						trapByDefault = FALSE;
						WritePrivateProfileString("Debug", "TrapByDefault", "Off", iniFile);
					} else {
						trapByDefault = TRUE;
						WritePrivateProfileString("Debug", "TrapByDefault", "On", iniFile);
					}
					break;
				case IDM_A_EXCEPTION:
					debugAction = DBG_EXCEPTION_NOT_HANDLED;
				case IDM_A_CONTINUE:
					EnableMenuItem(GetMenu(hWnd), IDM_A_CONTINUE, MF_BYCOMMAND | MF_GRAYED);
					EnableMenuItem(GetMenu(hWnd), IDM_A_EXCEPTION, MF_BYCOMMAND | MF_GRAYED);
					EnableMenuItem(GetMenu(hWnd), IDM_A_TRAP, MF_BYCOMMAND | MF_GRAYED);
					ResumeThread(hThread);
					break;

				case IDM_A_TRAP:
					if (clearAlways == TRUE) Clear(hwndSys);
					ShowStack(&excPtrs, TRUE);
					break;

				case IDM_A_STATE:
					DialogBox(hInst, "Debug_State_Dialog", hWnd, StateDlgProc);
					if (strcmp(module, "") != 0) {
						if (clearAlways==TRUE) Clear(hwndSys);
						ShowState(module);
					}
					break;
				case IDM_A_ALLSTACKS:{
					if (clearAlways==TRUE) Clear(hwndSys);
					ShowAllStacks();
					}
					break; 
				case IDM_A_STACK: {
						DWORD dw, i;
						OCHAR msg[128];

						DialogBox(hInst, "Debug_Stack_Dialog", hWnd, StackDlgProc);
						if (strcmp(module, "") != 0) {
							sscanf(module, "%lu", &dw);
							i = 0;
							while ((i < MAX_THREADS) && (threads[i].dwThreadId != dw)) {
								i++;
							}
							if (i < MAX_THREADS) {
								excPtrs.ExceptionRecord = (PEXCEPTION_RECORD)malloc(sizeof(EXCEPTION_RECORD));
								excPtrs.ContextRecord->ContextFlags = CONTEXT_FULL;
								GetThreadContext(threads[i].hThread, excPtrs.ContextRecord);
								excPtrs.ExceptionRecord->ExceptionCode = 0;
								excPtrs.ExceptionRecord->ExceptionAddress = (LPVOID)(excPtrs.ContextRecord->Eip);
								if (clearAlways==TRUE) Clear(hwndSys);
								ShowStack(&excPtrs, FALSE);
								
								free(excPtrs.ExceptionRecord);
							} else {
								if (clearAlways==TRUE) Clear(hwndSys);
								wsprintf(msg, "ShowStack %i\n", dw);
								String(hwndSys, msg);
								wsprintf(msg, "\tThread not found\n\n", dw);
								String(hwndSys, msg);
								Flush();
							}
						}
						break;
					}

				default:
					return DefFrameProc(hWnd, hwndMDIClient, uMsg, wParam, lParam);
					break;
			}
			break;

		case WM_CREATE: {
				CLIENTCREATESTRUCT ccs;
				INT i, j;

				proc.hThread = INVALID_HANDLE_VALUE;
				proc.hProcess = INVALID_HANDLE_VALUE;
				ccs.hWindowMenu = GetSubMenu(GetMenu(hWnd), IDM_W_POS);
				ccs.idFirstChild = IDM_WIN_CHILD;
				hwndMDIClient = CreateWindow("MDIClient", NULL, WS_CHILD | WS_CLIPCHILDREN |
					WS_VSCROLL | WS_HSCROLL, 0, 0, 0, 0, hWnd, (HMENU)ID_EDIT, hInst, (LPVOID)&ccs);
				ShowWindow(hwndMDIClient, SW_SHOW);
				hwndCon = CreateMDIWindow("Debug_Child_class", "Console", MDIS_ALLCHILDSTYLES |
					WS_CAPTION | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_THICKFRAME | WS_CLIPCHILDREN,
					CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, hwndMDIClient,
					hInst, (LPARAM)NULL);
				ShowWindow(hwndCon, SW_SHOW);
				hwndExc = CreateMDIWindow("Debug_Child_class", "Exception", MDIS_ALLCHILDSTYLES |
					WS_CAPTION | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_THICKFRAME | WS_CLIPCHILDREN,
					CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, hwndMDIClient,
					hInst, (LPARAM)NULL);
				ShowWindow(hwndExc, SW_SHOW);
				hwndSys = CreateMDIWindow("Debug_Child_class", "System", MDIS_ALLCHILDSTYLES |
					WS_CAPTION | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_THICKFRAME | WS_CLIPCHILDREN,
					CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, hwndMDIClient,
					hInst, (LPARAM)NULL);
				ShowWindow(hwndSys, SW_SHOW);
				PostMessage(hwndMDIClient, WM_MDITILE, 0, 0);

				GetModuleFileName(NULL, iniFile, MAX_PATH);
				i = 0; j = 0;
				while (iniFile[i] != (OCHAR)0) {
					if (iniFile[i] == '.') {
						j = i;
					}
					i++;
				}
				iniFile[j+1] = 'i'; iniFile[j+2] = 'n';
				iniFile[j+3] = 'i'; iniFile[j+4] = (OCHAR)0;
				strcpy(exePath, ""); strcpy(workPath, "");
				GetPrivateProfileString("Debug", "OnTop", workPath, exePath, MAX_PATH, iniFile);
				if (strcmp(exePath, "On") == 0) {
					CheckMenuItem(GetMenu(hWnd), IDM_W_ONTOP, MF_BYCOMMAND | MF_CHECKED);
					SetWindowPos(hWnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
				}
				GetPrivateProfileString("Debug", "Ignore", workPath, exePath, MAX_PATH, iniFile);
				if (strcmp(exePath, "On") == 0) {
					CheckMenuItem(GetMenu(hWnd), IDM_A_IGNORE, MF_BYCOMMAND | MF_CHECKED);
					ignoreExceptions = TRUE;
				}
				GetPrivateProfileString("Debug", "Clear", workPath, exePath, MAX_PATH, iniFile);
				if (strcmp(exePath, "On") == 0) {
					CheckMenuItem(GetMenu(hWnd), IDM_A_CLEARDEFAULT, MF_BYCOMMAND | MF_CHECKED);
					clearAlways = TRUE;
				}
				GetPrivateProfileString("Debug", "TrapByDefault", workPath, exePath, MAX_PATH, iniFile);
				if (strcmp(exePath, "Off") == 0) 
				{
					CheckMenuItem(GetMenu(hWnd), IDM_A_TRAPDEFAULT, MF_BYCOMMAND);
					trapByDefault = FALSE;
				} 
				else
				{
					CheckMenuItem(GetMenu(hWnd), IDM_A_TRAPDEFAULT, MF_BYCOMMAND | MF_CHECKED);
					trapByDefault = TRUE;
				}
				strcpy(exePath, ""); strcpy(workPath, "");				
				GetPrivateProfileString("Debug", "Exe", workPath, exePath, MAX_PATH, iniFile);
				excPtrs.ContextRecord = (PCONTEXT)malloc(sizeof(CONTEXT));
				break;
			}

    	case WM_CLOSE:
			SendMessage(hWnd, WM_STOP, 0, 0);
			DestroyWindow(hWnd);
			break;
		
		case WM_DESTROY:
			free(excPtrs.ContextRecord);
			PostQuitMessage(0);
        	break;

		default:
			return DefFrameProc(hWnd, hwndMDIClient, uMsg, wParam, lParam);
	}
	return 0;
}
