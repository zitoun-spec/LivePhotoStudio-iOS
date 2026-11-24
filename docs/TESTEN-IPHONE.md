# Testen op een fysieke iPhone

Noteer het iPhone-model, de iOS-versie, de gebruikte build en de bron per proef. Gebruik voor de duurproeven video’s met een zichtbare oplopende tijdcode en, waar vermeld, herkenbaar geluid aan het begin en einde.

| Proef | Invoer | Controle |
| --- | --- | --- |
| Foto’s, korte video | MP4 met H.264, 2–3 seconden, zonder audio | Videovoorbeeld, standaardhoofdframe, één nieuw item met de aanduiding **LIVE** in Foto’s. |
| Bestanden, korter dan 30 seconden | MP4 met H.264 en AAC, circa 12 seconden | Kies een hoofdframe dicht bij het einde en controleer dat het zichtbare frame overeenkomt met de gekozen tijd. Controleer begin en einde van het geluid. |
| Bestanden, langer dan 30 seconden | MOV met HEVC en AAC, circa 35–40 seconden | Controleer de weergegeven duur voor en na conversie. Controleer apart tot welke tijdcode het previewvenster en Foto’s afspelen. |
| Foto’s, langer dan een minuut | Verticale H.264- of HEVC-video, 60–90 seconden | Controleer de beeldverhouding, het gekozen hoofdframe, de duur in Foto’s en of het geluid tot het einde afspeelt. |
| Foto’s-toegang geweigerd | Willekeurige korte video | Weiger toegang en controleer dat de app geen opslagsucces meldt. Geef daarna toegang via Instellingen en probeer dezelfde opslag opnieuw. |

1. Importeer de video en speel het bronvoorbeeld af. Controleer de ingevoerde duur en het geluid. Zet zo nodig de stille modus uit en zet het mediavolume aan.
2. Tik op **Convert to Live Photo**. Controleer **Videoduur** en **Hoofdframe**. Meet bij het afspelen van het ingebouwde Live Photo-voorbeeld de eerste en laatste zichtbare tijdcode. Noteer een eventuele melding dat iOS geen voorbeeld kan openen.
3. Tik één keer op **Save Live Photo** en wacht op **Live Photo opgeslagen in Foto’s**, of noteer de foutmelding letterlijk. Controleer in **Foto’s → Recent bewaard** of er precies één nieuw item is. Open het item en controleer de aanduiding **LIVE** en het hoofdframe.
4. Houd de Live Photo ingedrukt. Noteer de eerste en laatste zichtbare tijdcode en of de laatste audio hoorbaar is. Als **Bewaar als video** beschikbaar is in het menu van Foto’s, kun je daarmee apart de geëxporteerde videoduur meten. Die meting zegt iets over de video die Foto’s exporteert. De tijdcodes bij het ingedrukt houden meten de gewone Live Photo-weergave.

| Bronduur | Voorbeeld (eerste → laatste tijdcode) | PhotoKit bevestigd | Eén LIVE-item | Foto’s (eerste → laatste tijdcode) | Audio-einde |
| --- | --- | --- | --- | --- | --- |
| | | | | | |

De simulatortests meten de opgeslagen bestanden van de conversie. Deze toestelproef is nodig om de acceptatie en afspeelduur in Apple Foto’s vast te stellen.
