<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<!-- 
  Purpose: Stylesheet to automatically add indexterms
           (Needed by db4index-profile.xsl)
  Author:  Thomas Schraitle
  Date:    2010-09-01
  
  How it works:
  The stylesheet distinguishes the following cases:
  
  1. The respective element is selected for adding indexterms.
     In this case, you do not have to do anything special. For
     example, if you want to add all <envar> elements, the
     stylesheet automatically adds an indexterm.
     
     Original text:
     <envar>PATH</envar>
     
     After processing:
     <envar>PATH</envar><indexterm>
        <primary>environment variables</primary>
        <secondary>PATH</secondary>
      </indexterm><indexterm>
        <primary>PATH</primary>
      </indexterm>
     
     If you get one or two <indexterm>s depends on the template
     for this element.
     The term "environment variables" is language dependent.
     
  2. For manually selecting to add an element into the index,
     insert condition="idx" or condition="index". This is the
     default action as described in (1). However, sometimes
     you want to change the default action (from automatically
     added, to automatically suppressed). In this case, only
     those elements were processed with the respective
     condition attributes set.
     
  3. For manually suppressing an element to be added into the
     index, insert condition="noidx" or condition="noindex".
     
 For those index entries which should be "preferred", use
 condition="idx-pref" or condition="index-pref". The prefix
 is controlled by the $idx.preferred parameter.
-->


<xsl:param name="idx.preferred">pref</xsl:param>

<xsl:template name="check.index">
  <xsl:param name="node" select="."/>
  <xsl:param name="default" select="1"/>

    <xsl:choose>
      <xsl:when test="$node/@condition = 'noindex'">0</xsl:when>
      <xsl:when test="$node/@condition = 'noidx'">0</xsl:when>
      <xsl:when test="$node/@condition = 'index'">1</xsl:when>
      <xsl:when test="$node/@condition = 'idx'">1</xsl:when>
      <xsl:otherwise><xsl:value-of select="$default"/></xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template name="check.preferred">
  <xsl:param name="node" select="."/>
  <xsl:if test="contains($node/@conformance, $idx.preferred)">
     <xsl:attribute name="significance">preferred</xsl:attribute>
  </xsl:if>
</xsl:template>

<xsl:template match="indexterm" mode="profile">
  <!-- Don't touch indexterms, just copy it -->
  <xsl:copy-of select="."/>
</xsl:template>

<xsl:template match="title" mode="profile">
  <!-- Don't touch titles, just copy it -->
  <xsl:copy-of select="."/>
</xsl:template>

<!--  -->
<xsl:template match="envar" mode="profile">
  <xsl:variable name="do.index">
    <xsl:call-template name="check.index"/>
  </xsl:variable>
  
  <!-- Copy original element -->
  <xsl:copy-of select="."/>
  
  <xsl:if test="$do.index != 0">
      <indexterm>
        <xsl:call-template name="check.preferred"/>
        <primary>environment variables</primary>
        <secondary>
          <xsl:value-of select="."/>
        </secondary>
      </indexterm>
  </xsl:if>
</xsl:template> 

<xsl:template match="filename[@class]" mode="profile">
  <xsl:variable name="do.index">
    <xsl:call-template name="check.index"/>
  </xsl:variable>
  
  <!-- Copy original element -->
  <xsl:copy-of select="."/>  
  <xsl:if test="$do.index != 0">
      <indexterm>
        <xsl:call-template name="check.preferred"/>
        <primary>
          <xsl:choose>
            <xsl:when test="@class='devicefile'">devices</xsl:when>
            <xsl:when test="@class='extension'">file extensions</xsl:when>
            <xsl:when test="@class='directory'">directories</xsl:when>
            <xsl:otherwise>              
              <xsl:text>** Other filenames[@class] **</xsl:text>
              <xsl:message>filename: Unknown @class=<xsl:value-of
                select="@class"/></xsl:message>
            </xsl:otherwise>
          </xsl:choose>
          
        </primary>
        <secondary>
          <xsl:value-of select="."/>
        </secondary>
      </indexterm>
  </xsl:if>
</xsl:template> 


<xsl:template match="sgmltag[@class='attribute']" mode="profile">
  <xsl:variable name="do.index">
    <xsl:call-template name="check.index"/>
  </xsl:variable>
  
  <!-- Copy original element -->
  <xsl:copy-of select="."/>
  <xsl:if test="$do.index != 0">
      <indexterm>
        <xsl:call-template name="check.preferred"/>
        <primary>attributes</primary>
        <secondary>
          <xsl:value-of select="."/>
        </secondary>
      </indexterm>
  </xsl:if>
</xsl:template>

<xsl:template match="systemitem[@class]" mode="profile">
  <xsl:variable name="do.index">
    <xsl:call-template name="check.index"/>
  </xsl:variable>
  
  <!-- Copy original element -->
  <xsl:copy-of select="."/>
  
  <xsl:if test="$do.index != 0">
    <indexterm>
      <xsl:call-template name="check.preferred"/>
      <primary>
        <xsl:choose>
          <xsl:when test="@class='service'">services</xsl:when>
          <xsl:when test="@class='server'">server</xsl:when>
          <xsl:when test="@class='filesystem'">filesystems</xsl:when>
          <xsl:when test="@class='protocol'">protocols</xsl:when>
          <xsl:when test="@class='macro'">macros</xsl:when>
          <xsl:otherwise>
            <xsl:text>** Other systemitems **</xsl:text>
            <xsl:message>systemitem: Unknown @class=<xsl:value-of
              select="@class"/></xsl:message>
          </xsl:otherwise>
        </xsl:choose>        
      </primary>
      <secondary>
        <!-- We are only interested in the string value -->
        <xsl:value-of select="."/>
      </secondary>
    </indexterm>
  </xsl:if>
</xsl:template>

</xsl:stylesheet>
