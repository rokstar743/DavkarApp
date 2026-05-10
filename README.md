# DavkarApp

Pretvori eToro Account Statement v XML datoteke za slovensko davčno napoved (FURS eDavki).

Podprti obrazci: **Doh-KDVP** (delnice), **D-IFI** (CFD), **Doh-Div** (dividende).

---

## ⚠️ Omejitev odgovornosti

Avtor aplikacije **NE prevzema odgovornosti** za napake v izvoženih podatkih. Pred oddajo na FURS vedno preveri generirane XML datoteke. Aplikacija ni davčni nasvet ali orodje.

---

## Namestitev

### 1. Prenesi

Pojdi na [Releases](https://github.com/rokstar743/DavkarApp/releases) in prenesi zadnjo verzijo (`DavkarApp-vX.X.zip`).

### 2. Razpakiraj

Razpakiraj zip datoteko kamorkoli na disku.

### 3. Poženi

Zaženi `davkarapp.exe`.

> `converter.exe` mora biti v **isti mapi** kot `davkarapp.exe` — ne premikaš samo exe-ja.

---

## Uporaba

1. V nastavitvah vnesi svojo davčno številko in ime
2. Klikni **Uvozi eToro poročilo** in izberi xlsx datoteko
3. Izberi davčno leto in klikni **Izračunaj**
4. Preveri transakcije in klikni **Izvozi XML**
5. XML datoteke so shranjene v `Dokumenti/DavkarApp/`