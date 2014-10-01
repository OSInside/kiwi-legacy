<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <xsl:template name="formal.object.heading">
  <xsl:param name="object" select="."/>
  <xsl:param name="title">
    <xsl:apply-templates select="$object" mode="object.title.markup">
      <xsl:with-param name="allow-anchors" select="1"/>
    </xsl:apply-templates>
  </xsl:param>

  <p class="title">
    <b>
      <xsl:copy-of select="$title"/>
    </b>
    
    <xsl:if test="@id">
      <xsl:call-template name="permalink">
        <xsl:with-param name="title" select="$title"/>
        <xsl:with-param name="id" select="@id"/>
      </xsl:call-template>
    </xsl:if>
  </p>
</xsl:template>
  
</xsl:stylesheet>
