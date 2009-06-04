<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:include href="/usr/share/kiwi/xsl/convert20to24.xsl"/>


<xsl:output method="xml" indent="yes" omit-xml-declaration="no"/>
<xsl:strip-space elements="type"/>

<xsl:template match="*|processing-instruction()|comment()" mode="conv24to35">
	<xsl:copy>
		<xsl:copy-of select="@*"/>
		<xsl:apply-templates mode="conv24to35"/>
	</xsl:copy>
</xsl:template>

<xsl:template match="/">
	<xsl:choose>
		<xsl:when test="image[@schemeversion='2.4']">
			<xsl:apply-templates mode="conv24to35"/>
		</xsl:when>
		<xsl:when test="image[@schemaversion='3.5']">
			<xsl:message terminate="yes">
				<xsl:text>Already at version 3.5... skipped</xsl:text>
			</xsl:message>
		</xsl:when>
		<xsl:otherwise>
			<xsl:message terminate="yes">
				<xsl:text>ERROR: Schema version is not correct.&#10;</xsl:text>
				<xsl:text>       but expected version 3.5.</xsl:text>
			</xsl:message>
		</xsl:otherwise>
	</xsl:choose>  
</xsl:template>

<para xmlns="http://docbook.org/ns/docbook">
	Changed attribute <tag class="attribute">schemeversion</tag>
	to <tag class="attribute">schemaversion</tag> from
	<literal>2.4</literal> to <literal>3.5</literal>.
</para>
<xsl:template match="image" mode="conv24to35">
	<image schemaversion="3.5">
		<xsl:copy-of select="@name"/>
		<xsl:apply-templates mode="conv24to35"/>
	</image>
</xsl:template>

<para xmlns="http://docbook.org/ns/docbook">
	Remove compressed element as it was moved into the type
</para>
<xsl:template match="node()|@*">
	<xsl:copy>
		<xsl:apply-templates select="node()|@*" mode="conv24to35"/>
	</xsl:copy>
</xsl:template>
<xsl:template match="compressed" mode="conv24to35"/>

</xsl:stylesheet>
