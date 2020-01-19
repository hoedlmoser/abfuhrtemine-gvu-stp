# abfuhrtemine-gvu-stp
exportiere die abfuhrtermine der NÖ Umweltverbände als iCalendar datei.

derzeit sind unterstützt:
- GVU St. Pölten Bezirk
- GVA Tulln

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
  --debug                    zeige entwicklerinformationen
```

