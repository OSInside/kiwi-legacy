<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:fo="http://www.w3.org/1999/XSL/Format"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:import
    href="http://docbook.sourceforge.net/release/xsl/current/fo/docbook.xsl"/>

  <xsl:param name="paper.type">A4</xsl:param>
  <xsl:param name="double.sided">1</xsl:param>

  <xsl:param name="body.start.indent">0pt</xsl:param>
  <xsl:param name="fop1.extensions" select="1"/>

  <!-- Format variablelists lists as blocks? -->
  <xsl:param name="variablelist.as.blocks" select="1"/>

  <!-- Use blocks for glosslists? -->
  <xsl:param name="glosslist.as.blocks" select="1"/>

  <xsl:param name="shade.verbatim" select="1"/>

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
  
  <!--
    <xsl:param name="toc.section.depth" select="3"/>
    <xsl:param name="toc.max.depth" select="4"/>
  -->
  
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

</xsl:stylesheet>
