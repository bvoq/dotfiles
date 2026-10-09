<TeXmacs|2.1.5>

<style|source>

<\body>
  <\active*>
    <\src-comment>
      bvoq's user comments.
    </src-comment>
  </active*>

  <\active*>
    <\src-comment>
      <senf> at the start of a title. The picture is a linked file, not an
      embedded one, and the macro itself is empty so the centered title keeps
      its width. The title macro paints the picture in the corner.
    </src-comment>
  </active*>

  <assign|senf|<macro|>>

  <drd-props|senf|arity|0|accessible|none>

  <assign|senf-picture|<macro|<image|$TEXMACS_HOME_PATH/misc/images/senf.png|3.6cm|||>>>

  <assign|senf-corner|<macro|<resize|<shift|<senf-picture>|0mm|-2.4mm>|||0mm|0mm>>>

  <\active*>
    <\src-comment>
      Same title bar as title-bar.ts. The argument stays an <arg> of this
      macro, so the title remains editable. Calling the previous tit from
      here showed <quote-arg|body> and blocked the cursor.
    </src-comment>
  </active*>

  <assign|tit|<\macro|body>
    <superpose|<\no-margins>
      <\surround|<assign|page-this-top|0mm>|<assign|gpag-length|<macro|<minus|1pag|<plus|<times|2|<value|title-vpadding>>|<times|<value|title-font-size>|1.5fn>|0.8fn|<value|par-par-sep>>>>>>
        <with|par-par-sep|0fn|color|<value|title-shadow-color>|font-size|<if|<value|title-old-style>|1|<value|title-font-size>>|<resize|<tabular*|<tformat|<twith|table-width|1par>|<twith|table-hmode|exact>|<cwith|1|1|1|-1|cell-tsep|<value|title-vpadding>>|<cwith|1|1|1|-1|cell-bsep|<value|title-vpadding>>|<cwith|1|1|1|-1|cell-background|<title-bar-color>>|<cwith|1|1|1|1|cell-halign|c>|<cwith|1|1|1|1|cell-hyphen|t>|<cwith|2|2|1|1|cell-vcorrect|n>|<cwith|2|2|1|1|cell-halign|l>|<twith|table-valign|T>|<cwith|1|1|1|1|cell-bborder|<value|title-border>>|<cwith|2|2|1|1|cell-hyphen|t>|<cwith|2|2|1|1|cell-lsep|0spc>|<cwith|2|2|1|1|cell-rsep|0spc>|<cwith|2|2|1|1|cell-bsep|0spc>|<cwith|2|2|1|1|cell-tsep|0spc>|<table|<row|<\cell>
          <with-tit-color|<title-left|<arg|body>><htab|5mm><arg|body><htab|5mm><title-right|<arg|body>>>
        </cell>>|<row|<\cell>
          <title-sub-bar-frame|<title-sub-bar-contents|<arg|body>>>
        </cell>>>>>||<plus|1b|0.2fn>||>>
      </surround>
    </no-margins>|<if|<extern|bvoqs-senf-leading?|<quote-arg|body>>|<senf-corner>|<resize||0mm|0mm|0mm|0mm>>>
  </macro>>
</body>

<\initial>
  <\collection>
    <associate|preamble|true>
  </collection>
</initial>
