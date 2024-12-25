# abfuhrtemine-gvu-stp

## eingestellt

dieses projekt wurde eingestellt, der GVU bzw die NÖ Umweltverbände bieten seit der saison 2025 einen direkten download von ics dateien an.

lediglich als kleine draufgabe ein sed script:
- tagestermine
- erinnerung am vortag um 16:00
- sprechende namen für müll-art

```
sed -E -e 's/^(DT(START|END).*)T[0-9]{6}/\1/g' \
       -e 's/^(TRIGGER:).*/\1-PT8H/g' \
       -e 's/(Bio)/\1tonne/g' \
       -e 's/LVP/Gelber Sack/g' \
       -e 's/Papier/Altpapier/g' \
       -e 's/(Restmüll) .PH/\1/g' \
       -e 's/Erinnerung: //g' \
  infile.ics > outfile.ics
```

## einführung

exportiere die abfuhrtermine der NÖ Umweltverbände als iCalendar ics datei.

derzeit sind unterstützt:
- GVU St. Pölten Bezirk
- GVA Tulln
- GVA Lilienfeld

fertige exporte gibts im verzeichnis `abfuhrtermine`.

## parameter

```
  --list                     zeige alle gemeinden
                             exportiere bzw zeige nur für ...
  --verbandid <verbandID>    ... einen bestimmten verband
  --gemeinde <gemeindename>  ... eine bestimmte gemeinde
  --gemeindeid <gemeindeID>  ... eine bestimmte gemeindeID
  --haushalt <e|m>           ... einen bestimmtem haushaltstyp
                                e ... einpersonenhaushalt
                                m ... mehrpersonenhaushalt
  --gebiet <1|2>             ... ein bestimmtes sammelgebiet 
  --jahr <jjjj>              standard aktuelles jahr
  --raw                      exportiere zusätzlich die rohdaten
  --text                     exportiere zusätzlich als text
  --debug                    zeige entwicklerinformationen
```

