# Voronoi Simulation

Ein interaktives Zwei-Spieler-Spiel in [Julia](https://julialang.org/), das auf Voronoi-Diagrammen basiert.
Ziel ist es, durch geschicktes Platzieren von Punkten möglichst große Flächen im Spielfeld zu kontrollieren.

---

## Einleitung

Das Projekt demonstriert Computational Geometry in der Praxis.
Jeder Spieler setzt abwechselnd Punkte, und nach einer festgelegten Anzahl von Zügen bestimmt das Voronoi-Diagramm die Flächenaufteilung.
Der Spieler mit der größten Gesamtfläche gewinnt.

---

## Mathematischer Hintergrund

* Voronoi-Diagramm: teilt den Raum in Regionen basierend auf nächstgelegenen Zentren.
* Delaunay-Triangulierung: duale Struktur zum Voronoi-Diagramm.
* Algorithmische Schritte:

  * Bounding-Triangle zur Initialisierung
  * Punktinsertion mit Dreiecksaufteilung
  * Edge-Flipping für die Delaunay-Bedingung
  * Voronoi-Berechnung mit Hexagon-Platzhaltern

Laufzeit im Durchschnitt: O(n).

---

## Softwarearchitektur

Das Projekt ist modular als Julia-Package aufgebaut:

* `datastructure.jl` – zentrale Datenstrukturen
* `delaunay.jl` – Delaunay-Triangulierung & Edge-Flipping
* `voronoi.jl` – Berechnung des Voronoi-Diagramms
* `visual.jl` – Visualisierung
* `VoronoiGame.jl` – Spielmechanik
* `tests/` – Unit-Tests (`runtests.jl`)
* `Project.toml` & `Manifest.toml` – Paketverwaltung

---

## Spielmechanik

* Zwei Spieler setzen abwechselnd Punkte.
* Nach *k* Zügen pro Spieler ist das Spiel vorbei.
* Das Voronoi-Diagramm teilt die Spielfläche auf.
* Sieger ist der Spieler mit der größten Fläche.

---

## Tests & Validierung

* Unit-Tests für alle Module
* Testabdeckung:

  * Datenstrukturen
  * Punktinsertion
  * Edge-Flipping
  * Flächenberechnung
* Shoelace-Formel zur Flächenberechnung
* Ausführung aller Tests über:

  ```bash
  julia --project=. test/runtests.jl
  ```

---

## Visualisierung & Ausblick

* Geplante GUI mit [Gtk4.jl](https://github.com/JuliaGraphics/Gtk4.jl)
* Features in Arbeit:

  * Spielfeld-Canvas mit Mausklick-Interaktion
  * Farbige Darstellung der Regionen
  * Gewinneranzeige am Spielende

---

## Installation & Nutzung

### Klonen

```bash
git clone https://github.com/jonathangoitom/voronoi_simulation.git
cd voronoi_simulation
```

### Starten

```bash
julia --project=.
include("VoronoiGame.jl")
```

---

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz (oder passende Lizenz ergänzen).

---

## Autoren

Dieses Projekt entstand als Arbeit im Rahmen einer Uni-Veranstaltung zu Computerorientierter Mathematik.
Maintainer: [@jonathangoitom](https://github.com/jonathangoitom)
