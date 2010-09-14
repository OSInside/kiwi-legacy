<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:fo="http://www.w3.org/1999/XSL/Format"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:import
    href="http://docbook.sourceforge.net/release/xsl/current/fo/docbook.xsl"/>

  <!-- Select the paper type                                  -->
  <xsl:param name="paper.type">A4</xsl:param>
  <!-- Is the document to be printed double sided?            -->
  <xsl:param name="double.sided">1</xsl:param>
  
  <!-- The start-indent for the body text                     -->
  <xsl:param name="body.start.indent">0pt</xsl:param>
  
  <!--  Enable extensions for FOP version 0.90 and later      -->
  <xsl:param name="fop1.extensions" select="1"/>

  <!-- Format variablelists lists as blocks?                  -->
  <xsl:param name="variablelist.as.blocks" select="1"/>

  <!-- Use blocks for glosslists?                             -->
  <xsl:param name="glosslist.as.blocks" select="1"/>

  <!-- Should verbatim environments be shaded?                -->
  <xsl:param name="shade.verbatim" select="1"/>

 <!-- Are sections enumerated?                                -->
 <xsl:param name="section.autolabel" select="1"/>
 <!-- Do section labels include the component label?          -->
 <xsl:param name="section.label.includes.component.label" select="1"/>
 
 <!-- How deep should recursive sections appear in the TOC?   -->
 <xsl:param name="toc.section.depth" select="1"/>
 <xsl:param name="generate.toc">
appendix  toc,title
article/appendix  nop
/article  toc,title
book      toc,title
chapter   toc,title
part      toc,title
/preface  toc,title
reference toc,title
 </xsl:param>

 <!-- Output NAME header before refnames?                     -->
 <xsl:param name="refentry.generate.name" select="0"/>

 <!-- Output title before refnames?                           --> 
 <xsl:param name="refentry.generate.title" select="1"/>

 <xsl:param name="callout.graphics" select="0"/>
 <xsl:param name="callout.unicode" select="1"/>
 <xsl:param name="callout.unicode.font">'DejaVu Sans'</xsl:param>
 <xsl:param name="callout.unicode.start.character">10122</xsl:param>



  <xsl:attribute-set name="shade.verbatim.style">
    <xsl:attribute name="background-color">#E0E0E0</xsl:attribute>
  </xsl:attribute-set>

  <xsl:attribute-set name="monospace.properties">
    <xsl:attribute name="font-size">
      <xsl:choose>
        <xsl:when test="ancestor::title">inherit</xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$body.font.master * 0.9"/>
          <xsl:text>pt</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:attribute>
  </xsl:attribute-set>
  <xsl:attribute-set name="monospace.verbatim.properties">
    <xsl:attribute name="font-size">
      <xsl:value-of select="$body.font.master * 0.8"/>
      <xsl:text>pt</xsl:text>
    </xsl:attribute>
  </xsl:attribute-set>
  <xsl:attribute-set name="verbatim.properties">
    <xsl:attribute name="wrap-option">wrap</xsl:attribute>
  </xsl:attribute-set>
  
  <xsl:attribute-set name="chapter.titlepage.recto.style">
    <xsl:attribute name="font-size">24.8832pt</xsl:attribute>
    <xsl:attribute name="font-weight">bold</xsl:attribute>
    <xsl:attribute name="font-family"><xsl:value-of select="$title.font.family"/></xsl:attribute>
  </xsl:attribute-set>
  
  <xsl:attribute-set name="appendix.titlepage.recto.style"
    use-attribute-sets="chapter.titlepage.recto.style"/>
  
  
  
  <xsl:param name="body.font.family">'Charis SIL'</xsl:param>
  <xsl:param name="title.font.family">'Charis SIL'</xsl:param>
  <!--<xsl:param name="sans.font.family"></xsl:param>-->
  <xsl:param name="monospace.font.family">'DejaVu Sans Mono'</xsl:param><!-- Liberation Mono -->
  
  <xsl:param name="body.font.master">11</xsl:param>


  <!-- Color codes for sgmltag[@class="..."] -->
  <xsl:param name="sgmltag.attribute.color">navy</xsl:param>
  <xsl:param name="sgmltag.attvalue.color">brown</xsl:param>
  <xsl:param name="sgmltag.starttag.color">navy</xsl:param>
  <xsl:param name="sgmltag.endtag.color">navy</xsl:param>


  <!-- ================= -->
  <xsl:template match="sgmltag|tag">
    <xsl:variable name="class">
      <xsl:choose>
        <xsl:when test="@class">
          <xsl:value-of select="@class"/>
        </xsl:when>
        <xsl:otherwise>element</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:choose>
      <xsl:when test="$class='attribute'">
        <fo:inline color="{$sgmltag.attribute.color}">
          <xsl:call-template name="inline.monoseq"/>
        </fo:inline>
      </xsl:when>
      <xsl:when test="$class='attvalue'">
        <fo:inline color="{$sgmltag.attvalue.color}">
          <xsl:call-template name="inline.monoseq"/>
        </fo:inline>
      </xsl:when>
      <xsl:when test="$class='element'">
        <xsl:call-template name="inline.monoseq"/>
      </xsl:when>
      <xsl:when test="$class='endtag'">
        <fo:inline color="{$sgmltag.starttag.color}">
          <xsl:call-template name="inline.monoseq">
            <xsl:with-param name="content">
              <xsl:text>&lt;/</xsl:text>
              <xsl:apply-templates/>
              <xsl:text>&gt;</xsl:text>
            </xsl:with-param>
          </xsl:call-template>
        </fo:inline>
      </xsl:when>
      <xsl:when test="$class='genentity'">
        <xsl:call-template name="inline.monoseq">
          <xsl:with-param name="content">
            <xsl:text>&amp;</xsl:text>
            <xsl:apply-templates/>
            <xsl:text>;</xsl:text>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$class='numcharref'">
        <xsl:call-template name="inline.monoseq">
          <xsl:with-param name="content">
            <xsl:text>&amp;#</xsl:text>
            <xsl:apply-templates/>
            <xsl:text>;</xsl:text>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$class='paramentity'">
        <xsl:call-template name="inline.monoseq">
          <xsl:with-param name="content">
            <xsl:text>%</xsl:text>
            <xsl:apply-templates/>
            <xsl:text>;</xsl:text>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$class='pi'">
        <xsl:call-template name="inline.monoseq">
          <xsl:with-param name="content">
            <xsl:text>&lt;?</xsl:text>
            <xsl:apply-templates/>
            <xsl:text>&gt;</xsl:text>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$class='xmlpi'">
        <xsl:call-template name="inline.monoseq">
          <xsl:with-param name="content">
            <xsl:text>&lt;?</xsl:text>
            <xsl:apply-templates/>
            <xsl:text>?&gt;</xsl:text>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$class='starttag'">
        <fo:inline color="{$sgmltag.starttag.color}" font-family="{$monospace.font.family}">
            <xsl:text>&lt;</xsl:text>
            <xsl:apply-templates/>
            <xsl:text>&gt;</xsl:text>
        </fo:inline>
      </xsl:when>
      <xsl:when test="$class='emptytag'">
          <fo:inline font-family="{$monospace.font.family}">
            <xsl:text>&lt;</xsl:text>
            <xsl:apply-templates/>
            <xsl:text>/&gt;</xsl:text>
          </fo:inline>
      </xsl:when>
      <xsl:when test="$class='sgmlcomment' or $class='comment'">
        <fo:inline>
          <xsl:text>&lt;!--</xsl:text>
          <xsl:apply-templates/>
          <xsl:text>--&gt;</xsl:text>
        </fo:inline>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="inline.charseq"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Titlepages -->
  <xsl:template match="authorgroup"
    mode="book.titlepage.recto.auto.mode">
    <!-- Only authors appear on the recto titlepage -->
    <fo:block space-before="30pt">
      <xsl:apply-templates select="author"
        mode="book.titlepage.recto.mode"/>
    </fo:block>
  </xsl:template>

  <xsl:template match="author" mode="titlepage.mode">
    <fo:block xsl:use-attribute-sets="book.titlepage.recto.style"
      font-size="17.28pt" space-before="10.8pt"
      keep-with-next.within-column="always">
      <xsl:call-template name="anchor"/>
      <xsl:call-template name="person.name"/>
      <!--<xsl:if test="email|affiliation/address/email">
      <xsl:text> </xsl:text>
      <xsl:apply-templates select="(email|affiliation/address/email)[1]"/>
    </xsl:if>-->
    </fo:block>
  </xsl:template>

  <xsl:template match="title" mode="book.titlepage.recto.auto.mode">
    <fo:block>&#xa0;</fo:block>
    <fo:block xsl:use-attribute-sets="book.titlepage.recto.style"
      text-align="center" font-size="24.8832pt" space-before="180pt"
      font-weight="bold" font-family="{$title.fontset}">
      <xsl:call-template name="division.title">
        <xsl:with-param name="node" select="ancestor-or-self::book[1]"/>
      </xsl:call-template>
    </fo:block>
  </xsl:template>

  <!-- Recto titlepage -->
  <xsl:template match="author" mode="book.titlepage.verso.auto.mode">
    <fo:block xsl:use-attribute-sets="book.titlepage.verso.style"
      space-after="2em">
      <xsl:apply-templates select="." mode="book.titlepage.verso.mode"/>
    </fo:block>
  </xsl:template>

  <xsl:template match="othercredit" mode="titlepage.mode">
    <xsl:variable name="contrib" select="string(contrib)"/>
    <fo:block>
      <xsl:call-template name="person.name"/>
      <xsl:if test="email|affiliation/address/email">
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="(email|affiliation/address/email)[1]"/>
      </xsl:if>
    </fo:block>
    
    <!--<xsl:choose>
      <xsl:when test="contrib">
        <xsl:if
          test="not(preceding-sibling::othercredit[string(contrib)=$contrib])">
          <fo:block>
            <xsl:apply-templates mode="titlepage.mode" select="contrib"/>
            <xsl:text>: </xsl:text>
            <xsl:call-template name="person.name"/>
            <xsl:apply-templates mode="titlepage.mode"
              select="affiliation"/>
            <xsl:apply-templates
              select="following-sibling::othercredit[string(contrib)=$contrib]"
              mode="titlepage.othercredits"/>
          </fo:block>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <fo:block>
          <xsl:call-template name="person.name"/>
        </fo:block>
        <xsl:apply-templates mode="titlepage.mode"
          select="./affiliation"/>
      </xsl:otherwise>
    </xsl:choose>-->
  </xsl:template>

  <xsl:template name="toc.line">
    <xsl:param name="toc-context" select="NOTANODE"/>
    <xsl:variable name="id">
      <xsl:call-template name="object.id"/>
    </xsl:variable>

    <xsl:variable name="label">
      <xsl:apply-templates select="." mode="label.markup"/>
    </xsl:variable>

    <!-- FOP HACK: If space-before would work, this code would not be
      necessary
    -->
    <xsl:if test="$fop1.extensions != 0 and 
                  (self::appendix or self::chapter or self::index or
                   self::glossary or self::bibliography)">
      <fo:block font-size="0.75em">&#xa0;</fo:block>
    </xsl:if>
    
    <fo:block xsl:use-attribute-sets="toc.line.properties">
      <fo:inline keep-with-next.within-line="always" >
        <fo:basic-link internal-destination="{$id}">
          <xsl:if test="self::appendix or self::chapter or self::index or
                   self::glossary or self::bibliography">
            <xsl:attribute name="font-weight">bold</xsl:attribute>
            <xsl:attribute name="space-before">1em</xsl:attribute>
          </xsl:if>

          <xsl:if test="$label != ''">
            <xsl:copy-of select="$label"/>
            <xsl:value-of select="$autotoc.label.separator"/>
          </xsl:if>
          <xsl:apply-templates select="." mode="title.markup"/>
        </fo:basic-link>
      </fo:inline>
      <fo:inline keep-together.within-line="always">
        <xsl:text> </xsl:text>
        <fo:leader leader-pattern="dots" leader-pattern-width="3pt"
          leader-alignment="reference-area"
          keep-with-next.within-line="always"/>
        <xsl:text> </xsl:text>
        <fo:basic-link internal-destination="{$id}">
          <fo:page-number-citation ref-id="{$id}"/>
        </fo:basic-link>
      </fo:inline>
    </fo:block>
  </xsl:template>

  <xsl:template name="chapappendix.title">
    <xsl:param name="node" select="."/>
    <xsl:variable name="nodepi" select="$node"/>
    <xsl:variable name="id">
      <xsl:call-template name="object.id">
        <xsl:with-param name="object" select="$node"/>
      </xsl:call-template>
    </xsl:variable>

    <fo:block>
      <xsl:choose>
        <xsl:when test="$fop1.extensions != 0">
          <xsl:attribute name="margin-top">4em</xsl:attribute>
        </xsl:when>
        <xsl:otherwise>
          <xsl:attribute name="space-before">4em</xsl:attribute>
        </xsl:otherwise>
      </xsl:choose>
      
      <xsl:apply-templates select="$nodepi" mode="label.markup"/>
      <fo:leader leader-length=".75em" leader-pattern="space"/>
      <xsl:apply-templates select="$nodepi" mode="title.markup"/>
    </fo:block>
  </xsl:template>
  
  <xsl:template match="title" mode="chapter.titlepage.recto.auto.mode">
    <fo:block xsl:use-attribute-sets="chapter.titlepage.recto.style"
      font-family="{$title.font.family}">
      <xsl:call-template name="chapappendix.title">
        <xsl:with-param name="node"
          select="ancestor-or-self::chapter[1]"/>
      </xsl:call-template>
    </fo:block>
  </xsl:template>

  <xsl:template match="title" mode="appendix.titlepage.recto.auto.mode">
    <fo:block xsl:use-attribute-sets="appendix.titlepage.recto.style"
      font-family="{$title.font.family}">
      <xsl:call-template name="chapappendix.title">
        <xsl:with-param name="node"
          select="ancestor-or-self::appendix[1]"/>
      </xsl:call-template>
    </fo:block>
  </xsl:template>

  <!--  -->
  <xsl:template name="callout-bug">
  <xsl:param name="conum" select='1'/>

  <xsl:choose>
    <!-- Draw callouts as images -->
    <xsl:when test="$callout.graphics != '0'
                    and $conum &lt;= $callout.graphics.number.limit">
      <xsl:variable name="filename"
                    select="concat($callout.graphics.path, $conum,
                                   $callout.graphics.extension)"/>

      <fo:external-graphic content-width="{$callout.icon.size}"
                           width="{$callout.icon.size}">
        <xsl:attribute name="src">
          <xsl:choose>
            <xsl:when test="$passivetex.extensions != 0
                            or $fop.extensions != 0
                            or $arbortext.extensions != 0">
              <xsl:value-of select="$filename"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>url(</xsl:text>
              <xsl:value-of select="$filename"/>
              <xsl:text>)</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
      </fo:external-graphic>
    </xsl:when>
    <xsl:when test="$callout.unicode != 0
                    and $conum &lt;= $callout.unicode.number.limit">
      <xsl:variable name="comarkup">
        <xsl:choose>
          <xsl:when test="$callout.unicode.start.character = 10102">
            <xsl:choose>
              <xsl:when test="$conum = 1">&#10102;</xsl:when>
              <xsl:when test="$conum = 2">&#10103;</xsl:when>
              <xsl:when test="$conum = 3">&#10104;</xsl:when>
              <xsl:when test="$conum = 4">&#10105;</xsl:when>
              <xsl:when test="$conum = 5">&#10106;</xsl:when>
              <xsl:when test="$conum = 6">&#10107;</xsl:when>
              <xsl:when test="$conum = 7">&#10108;</xsl:when>
              <xsl:when test="$conum = 8">&#10109;</xsl:when>
              <xsl:when test="$conum = 9">&#10110;</xsl:when>
              <xsl:when test="$conum = 10">&#10111;</xsl:when>
            </xsl:choose>
          </xsl:when>
          <xsl:when test="$callout.unicode.start.character = 10122">
            <xsl:choose>
              <xsl:when test="$conum = 1">&#10122;</xsl:when>
              <xsl:when test="$conum = 2">&#10123;</xsl:when>
              <xsl:when test="$conum = 3">&#10124;</xsl:when>
              <xsl:when test="$conum = 4">&#10125;</xsl:when>
              <xsl:when test="$conum = 5">&#10126;</xsl:when>
              <xsl:when test="$conum = 6">&#10127;</xsl:when>
              <xsl:when test="$conum = 7">&#10128;</xsl:when>
              <xsl:when test="$conum = 8">&#10129;</xsl:when>
              <xsl:when test="$conum = 9">&#10130;</xsl:when>
              <xsl:when test="$conum = 10">&#10131;</xsl:when>
            </xsl:choose>
          </xsl:when>
          <xsl:otherwise>
            <xsl:message>
              <xsl:text>Don't know how to generate Unicode callouts </xsl:text>
              <xsl:text>when $callout.unicode.start.character is </xsl:text>
              <xsl:value-of select="$callout.unicode.start.character"/>
            </xsl:message>
            <fo:inline background-color="#404040"
                       color="white"
                       padding-top="0.1em"
                       padding-bottom="0.1em"
                       padding-start="0.2em"
                       padding-end="0.2em"
                       baseline-shift="0.1em"
                       font-family="{$body.fontset}"
                       font-weight="bold"
                       font-size="75%">
              <xsl:value-of select="$conum"/>
            </fo:inline>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:choose>
        <xsl:when test="$callout.unicode.font != ''">
          <fo:inline font-family="{$callout.unicode.font}">
            <xsl:copy-of select="$comarkup"/>
          </fo:inline>
        </xsl:when>
        <xsl:otherwise>
          <xsl:copy-of select="$comarkup"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>

    <!-- Most safe: draw a dark gray square with a white number inside -->
    <xsl:otherwise>
      <fo:inline background-color="#404040"
                 color="white"
                 padding-top="0.1em"
                 padding-bottom="0.1em"
                 padding-start="0.2em"
                 padding-end="0.2em"
                 baseline-shift="0.1em"
                 font-family="{$body.fontset}"
                 font-weight="bold"
                 font-size="75%">
        <xsl:value-of select="$conum"/>
      </fo:inline>
    </xsl:otherwise>
  </xsl:choose>
  </xsl:template>
  
</xsl:stylesheet>
